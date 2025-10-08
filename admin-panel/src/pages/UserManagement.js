import React, { useState, useEffect } from 'react';
import { 
  PlusIcon, 
  PencilIcon, 
  MagnifyingGlassIcon,
  EyeIcon,
  XCircleIcon,
  CheckCircleIcon
} from '@heroicons/react/24/outline';
import { format } from 'date-fns';
import toast from 'react-hot-toast';



// Helper function to get authentication token
const getAuthToken = () => {
  const token = localStorage.getItem('admin_token');
  if (!token || token === 'null' || token === 'undefined') {
    // No valid authentication token found
    toast.error('Authentication required. Please log in again.');
    return null;
  }
  return token;
};


// Helper component to display fish information in a clean format
// const FishInfo = ({ fish, index }) => {
//   if (!fish) return null;
//   
//   return (
//     <div key={index} className="bg-gray-50 p-3 rounded-lg border border-gray-200 mb-3">
//       <h6 className="font-medium text-gray-800 mb-2">{fish.species || 'Unknown Fish'}</h6>
//       <div className="grid grid-cols-2 gap-2 text-sm">
//         {fish.quantity && <InfoRow label="Quantity" value={fish.quantity} />}
//         {fish.portion_grams && <InfoRow label="Portion per fish" value={fish.portion_grams} unit="g" />}
//         {fish.diet && <InfoRow label="Diet" value={fish.diet} />}
//         {fish.preferred_food && <InfoRow label="Preferred Food" value={fish.preferred_food} />}
//       </div>
//     </div>
//   );
// };

// Helper component to display feed inventory items
// const FeedItem = ({ feed, index }) => {
//   if (!feed) return null;
//   
//   return (
//     <div key={index} className="bg-gray-50 p-3 rounded-lg border border-gray-200 mb-3">
//       <h6 className="font-medium text-gray-800 mb-2">{feed.feed_type || 'Feed'}</h6>
//       <div className="grid grid-cols-2 gap-2 text-sm">
//         {feed.quantity && <InfoRow label="Quantity" value={feed.quantity} unit="g" />}
//         {feed.days_remaining && <InfoRow label="Days Remaining" value={feed.days_remaining} />}
//         {feed.last_updated && (
//           <InfoRow 
//             label="Last Updated" 
//             value={format(new Date(feed.last_updated), 'MMM dd, yyyy')} 
//             className="col-span-2"
//           />
//         )}
//       </div>
//     </div>
//   );
// };

function UserManagement() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [modalMode, setModalMode] = useState('view');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);
  const [showStatusDialog, setShowStatusDialog] = useState(false);
  const [userToToggle, setUserToToggle] = useState(null);
  const [userActivities, setUserActivities] = useState({
    fish_predictions: [],
    water_calculations: [],
    fish_calculations: [],
    diet_calculations: [],
    fish_volume_calculations: [],
    compatibility_results: [],
    tanks: []
  });
  const [loadingActivities, setLoadingActivities] = useState(false);

  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      const token = getAuthToken();
      if (!token) return;
      
      // Add cache-busting parameter to ensure fresh data
      const timestamp = new Date().getTime();
      const response = await fetch(`/api/users?t=${timestamp}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache'
        }
      });
      
      if (response.status === 401) {
        toast.error('Authentication expired. Please log in again.');
        return;
      }
      
      const data = await response.json();
      // Data fetched successfully - no need to log sensitive information
      
      setUsers(Array.isArray(data) ? data : []);
    } catch (error) {
      toast.error('Failed to fetch users data');
      // Error fetching users data
      setUsers([]); // Ensure users is always an array
    } finally {
      setLoading(false);
    }
  };

  const handleViewUser = async (userData) => {
    setSelectedUser(userData);
    setModalMode('view');
    setShowModal(true);
    await fetchUserActivities(userData.id);
  };

  const fetchUserActivities = async (userId) => {
    setLoadingActivities(true);
    try {
      const token = getAuthToken();
      if (!token) return;
      
      const activities = {};
      
      // Fetch all activity types in parallel
      const activityTypes = [
        'fish_predictions',
        'water_calculations', 
        'fish_calculations',
        'diet_calculations',
        'fish_volume_calculations',
        'compatibility_results',
        'tanks'
      ];

      const promises = activityTypes.map(async (tableName) => {
        try {
          const response = await fetch(`/api/users/${userId}/activities/${tableName}`, {
        headers: {
          'Authorization': `Bearer ${token}`,
              'Content-Type': 'application/json',
            },
          });
          
          if (response.ok) {
            const data = await response.json();
            return { tableName, data: data || [] };
          } else {
            // Failed to fetch data
            return { tableName, data: [] };
          }
        } catch (error) {
          // Error fetching data
          return { tableName, data: [] };
        }
      });

      const results = await Promise.all(promises);
      
      results.forEach(({ tableName, data }) => {
        activities[tableName] = data;
      });

      setUserActivities(activities);
    } catch (error) {
      // Error fetching user activities
      toast.error('Failed to load user activities');
    } finally {
      setLoadingActivities(false);
    }
  };

  const handleAddUser = () => {
    setSelectedUser({
      email: '',
      active: true
    });
    setModalMode('add');
    setShowModal(true);
  };

  const handleEditUser = (userData) => {
    setSelectedUser(userData);
    setModalMode('edit');
    setShowModal(true);
  };


  const handleSaveUser = async (userData) => {
    try {
      const token = getAuthToken();
      if (!token) return;
      
      // Clean the data - only send fields that should be updated
      const cleanedData = {
        email: userData.email?.trim(),
        active: Boolean(userData.active)
      };
      
      // Remove empty strings and null values
      Object.keys(cleanedData).forEach(key => {
        if (cleanedData[key] === '' || cleanedData[key] === null || cleanedData[key] === undefined) {
          delete cleanedData[key];
        }
      });
      
      // Basic validation
      if (cleanedData.email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanedData.email)) {
        toast.error('Please enter a valid email address');
        return;
      }
      
      // Sending user data to server
      
      const url = modalMode === 'add' ? '/api/users' : `/api/users/${userData.id}`;
      const method = modalMode === 'add' ? 'POST' : 'PUT';
      
      const response = await fetch(url, {
        method,
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(cleanedData),
      });

      if (response.status === 401) {
        toast.error('Authentication expired. Please log in again.');
        return;
      }

      if (response.status === 400) {
        const errorData = await response.json();
        // Bad Request Error
        if (errorData.errors && errorData.errors.length > 0) {
          // Validation errors occurred
          const errorMessages = errorData.errors.map(err => `${err.path}: ${err.msg}`).join(', ');
          toast.error(`Validation failed: ${errorMessages}`);
        } else {
          toast.error(`Validation Error: ${errorData.message || 'Invalid data provided'}`);
        }
        return;
      }

      if (response.ok) {
        toast.success(`User ${modalMode === 'add' ? 'created' : 'updated'} successfully`);
        setShowModal(false);
        fetchUsers();
      } else {
        const errorData = await response.json();
        // Save Error occurred
        toast.error(`Failed to ${modalMode === 'add' ? 'create' : 'update'} user: ${errorData.message || 'Unknown error'}`);
      }
    } catch (error) {
      toast.error(`Error ${modalMode === 'add' ? 'creating' : 'updating'} user`);
      console.error('Error:', error);
    }
  };

  const handleToggleUserStatus = (userId, currentStatus) => {
    setUserToToggle({ id: userId, currentStatus });
    setShowStatusDialog(true);
  };

  const confirmToggleStatus = async () => {
    if (!userToToggle) return;
    
    try {
      const newStatus = !(userToToggle.currentStatus === true || userToToggle.currentStatus === 'true');
      const token = getAuthToken();
      if (!token) return;
      
      // Toggling user status
      
      const response = await fetch(`/api/users/${userToToggle.id}/status`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ active: newStatus }),
      });

      // Status update response received

      if (response.status === 401) {
        toast.error('Authentication expired. Please log in again.');
        return;
      }

      if (response.ok) {
        await response.json();
        // Status update successful
        toast.success(`User ${newStatus ? 'activated' : 'deactivated'} successfully`);
        
        // Force refresh the users list
        await fetchUsers();
      } else {
        const errorData = await response.json();
        // Status update error occurred
        toast.error(`Failed to update user status: ${errorData.message || 'Unknown error'}`);
      }
    } catch (error) {
      toast.error('Error updating user status');
      console.error('Error:', error);
    } finally {
      setShowStatusDialog(false);
      setUserToToggle(null);
    }
  };

  const filteredUsers = users.filter(user => {
    // Hide admin users from frontend
    // Check multiple possible admin indicators
    const isAdmin = user.role === 'admin' || 
                   user.email === 'admin@aquasync.com' ||
                   (user.email && user.email.toLowerCase().includes('admin'));
    
    if (isAdmin) {
      // Filtering out admin user from display
      return false;
    }
    
    const matchesSearch = user.email?.toLowerCase().includes(searchTerm.toLowerCase());
    
    return matchesSearch;
  });

  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = filteredUsers.slice(indexOfFirstItem, indexOfLastItem);
  const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-aqua-500"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="sm:flex sm:items-center mb-6">
        <div className="sm:flex-auto">
          <h1 className="text-2xl font-semibold text-gray-900">User Management</h1>
          <p className="mt-2 text-sm text-gray-700">
            Manage user accounts and profiles from Supabase Authentication
          </p>
        </div>
        <div className="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <button
            type="button"
            onClick={handleAddUser}
            className="inline-flex items-center justify-center rounded-md border border-transparent bg-aqua-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-aqua-700 focus:outline-none focus:ring-2 focus:ring-aqua-500 focus:ring-offset-2 sm:w-auto"
          >
            <PlusIcon className="h-4 w-4 mr-2" />
            Add User
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="mb-6">
        <div className="relative">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" />
          </div>
          <input
            type="text"
            className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500 sm:text-sm"
            placeholder="Search users by email..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
          />
        </div>
      </div>

      {/* Users Table - Desktop View */}
      <div className="hidden md:block bg-white shadow overflow-hidden sm:rounded-md">
        <div className="table-container">
          <table className="table-mobile">
            <thead className="bg-gray-50">
              <tr>
                <th className="table-mobile-header">Email</th>
                <th className="table-mobile-header">Status</th>
                <th className="table-mobile-header">Created</th>
                <th className="table-mobile-header">Actions</th>
              </tr>
            </thead>
            <tbody className="bg-white divide-y divide-gray-200">
              {currentItems.map((user) => (
                <tr key={user.id} className="hover:bg-gray-50">
                  <td className="table-mobile-cell">
                    {user.email || 'N/A'}
                  </td>
                  <td className="table-mobile-cell">
                    <span className={`status-badge ${
                      user.active === true || user.active === 'true'
                        ? 'status-badge-green'
                        : 'status-badge-red'
                    }`}>
                      {user.active === true || user.active === 'true' ? 'Active' : 'Inactive'}
                    </span>
                  </td>
                  <td className="table-mobile-cell">
                    <div className="text-sm text-gray-500">
                      {user.updated_at ? format(new Date(user.updated_at), 'MMM dd, yyyy') : 'N/A'}
                    </div>
                  </td>
                  <td className="table-mobile-cell">
                    <div className="flex space-x-2">
                      <button
                        type="button"
                        onClick={() => handleViewUser(user)}
                        className="text-aqua-600 hover:text-aqua-900"
                        title="View Details"
                      >
                        <EyeIcon className="h-4 w-4" />
                      </button>
                      <button
                        type="button"
                        onClick={() => handleToggleUserStatus(user.id, user.active)}
                        className={`${
                          user.active === true || user.active === 'true'
                            ? 'text-red-600 hover:text-red-900'
                            : 'text-green-600 hover:text-green-900'
                        }`}
                        title={user.active === true || user.active === 'true' ? 'Deactivate User' : 'Activate User'}
                      >
                        {user.active === true || user.active === 'true' ? (
                          <XCircleIcon className="h-4 w-4" />
                        ) : (
                          <CheckCircleIcon className="h-4 w-4" />
                        )}
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Users Cards - Mobile View */}
      <div className="md:hidden space-y-4">
        {currentItems.map((user) => (
          <div key={user.id} className="mobile-card">
            <div className="mobile-card-header">
              <div>
                <h3 className="mobile-card-title">{user.email || 'N/A'}</h3>
                <p className="mobile-card-subtitle">
                  {user.updated_at ? format(new Date(user.updated_at), 'MMM dd, yyyy') : 'N/A'}
                </p>
              </div>
              <span className={`status-badge ${
                user.active === true || user.active === 'true'
                  ? 'status-badge-green'
                  : 'status-badge-red'
              }`}>
                {user.active === true || user.active === 'true' ? 'Active' : 'Inactive'}
              </span>
            </div>
            
            <div className="mobile-card-actions">
              <button
                type="button"
                onClick={() => handleViewUser(user)}
                className="mobile-action-btn mobile-action-btn-primary"
                title="View Details"
              >
                <EyeIcon className="h-4 w-4 mr-1" />
                View
              </button>
              <button
                type="button"
                onClick={() => handleToggleUserStatus(user.id, user.active)}
                className={`mobile-action-btn ${
                  user.active === true || user.active === 'true'
                    ? 'mobile-action-btn-danger'
                    : 'mobile-action-btn-primary'
                }`}
                title={user.active === true || user.active === 'true' ? 'Deactivate User' : 'Activate User'}
              >
                {user.active === true || user.active === 'true' ? (
                  <>
                    <XCircleIcon className="h-4 w-4 mr-1" />
                    Deactivate
                  </>
                ) : (
                  <>
                    <CheckCircleIcon className="h-4 w-4 mr-1" />
                    Activate
                  </>
                )}
              </button>
            </div>
          </div>
        ))}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-6 flex items-center justify-between">
          <div className="text-sm text-gray-700">
            Showing {indexOfFirstItem + 1} to {Math.min(indexOfLastItem, filteredUsers.length)} of {filteredUsers.length} results
          </div>
          <div className="flex space-x-2">
            <button
              type="button"
              onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
              disabled={currentPage === 1}
              className="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
            >
              Previous
            </button>
            <span className="px-3 py-2 text-sm text-gray-700">
              Page {currentPage} of {totalPages}
            </span>
            <button
              type="button"
              onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
              disabled={currentPage === totalPages}
              className="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {/* User Modal */}
      {showModal && (
        <UserModal
          user={selectedUser}
          mode={modalMode}
          onSave={handleSaveUser}
          onClose={() => setShowModal(false)}
          activities={userActivities}
          loadingActivities={loadingActivities}
        />
      )}

      {/* Status Toggle Confirmation Dialog */}
      {showStatusDialog && (
        <StatusConfirmDialog
          isOpen={showStatusDialog}
          onClose={() => setShowStatusDialog(false)}
          onConfirm={confirmToggleStatus}
          userStatus={userToToggle?.currentStatus}
        />
      )}

    </div>
  );
}

function UserModal({ user, mode, onSave, onClose, activities, loadingActivities }) {
  const [formData, setFormData] = useState(user);
  const [activeTab, setActiveTab] = useState('profile');

  // Update formData when user prop changes
  useEffect(() => {
    setFormData(user);
  }, [user]);

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave(formData);
  };

  const isReadOnly = mode === 'view';

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-10 mx-auto p-5 border w-11/12 max-w-6xl shadow-lg rounded-md bg-white">
        <div className="mt-3">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              {mode === 'add' ? 'Add New User' : 
               mode === 'edit' ? 'Edit User' : 'User Details'}
            </h3>
            <button
              type="button"
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600"
            >
              <span className="sr-only">Close</span>
              ×
            </button>
          </div>

          {/* Tabs for Profile and Activities */}
          {isReadOnly && (
            <div className="border-b border-gray-200 mb-6">
              <nav className="-mb-px flex space-x-8">
                <button
                  onClick={() => setActiveTab('profile')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'profile'
                      ? 'border-aqua-500 text-aqua-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Profile Information
                </button>
                <button
                  onClick={() => setActiveTab('activities')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'activities'
                      ? 'border-aqua-500 text-aqua-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  User Activities
                </button>
              </nav>
            </div>
          )}

          {activeTab === 'profile' ? (
            <form onSubmit={handleSubmit} className="space-y-6">
              {/* Profile Information */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <label className="block text-sm font-medium text-gray-700">Email</label>
                  <input
                    type="email"
                    name="email"
                    value={formData.email || ''}
                    onChange={handleChange}
                    readOnly={isReadOnly}
                    className="input-field"
                    required={mode === 'add'}
                  />
                </div>

                {isReadOnly && (
                  <>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Created At</label>
                      <div className="mt-1 text-sm text-gray-900">
                        {formData.created_at ? format(new Date(formData.created_at), 'PPpp') : 'N/A'}
                      </div>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700">Last Sign In</label>
                      <div className="mt-1 text-sm text-gray-900">
                        {formData.last_sign_in_at ? format(new Date(formData.last_sign_in_at), 'PPpp') : 'Never'}
                      </div>
                    </div>

                    <div>
                      <label className="block text-sm font-medium text-gray-700">Status</label>
                      <div className="mt-1">
                        <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                          formData.active === true || formData.active === 'true'
                            ? 'bg-green-100 text-green-800'
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {formData.active === true || formData.active === 'true' ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                    </div>
                  </>
                )}
              </div>

              {!isReadOnly && (
                <div className="flex justify-end space-x-3 pt-6 border-t">
                  <button
                    type="button"
                    onClick={onClose}
                    className="btn-secondary"
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    className="btn-primary"
                  >
                    {mode === 'add' ? 'Add User' : 'Update User'}
                  </button>
                </div>
              )}
            </form>
          ) : (
            <UserActivitiesSection activities={activities} loading={loadingActivities} />
          )}
        </div>
      </div>
    </div>
  );
}

// Status Toggle Confirmation Dialog Component
function StatusConfirmDialog({ isOpen, onClose, onConfirm, userStatus }) {
  if (!isOpen) return null;

  const isCurrentlyActive = userStatus === true || userStatus === 'true';
  const newStatus = !isCurrentlyActive;
                                                
                                                return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
        <div className="mt-3">
          <div className="flex items-center justify-center w-12 h-12 mx-auto mb-4 rounded-full bg-orange-100">
            <svg className="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.268 19.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
                                                    </div>
                                                    
          <div className="text-center">
            <h3 className="text-lg font-medium text-gray-900 mb-2">
              {newStatus ? 'Activate User' : 'Deactivate User'}
            </h3>
            <div className="mt-2 px-7 py-3">
              <p className="text-sm text-gray-500">
                Are you sure you want to {newStatus ? 'activate' : 'deactivate'} this user?
                {!newStatus && (
                  <span className="block mt-2 text-red-600 font-medium">
                    The user will not be able to access the system.
                                                              </span>
                )}
                {newStatus && (
                  <span className="block mt-2 text-green-600 font-medium">
                    The user will be able to access the system again.
                  </span>
                )}
              </p>
                              </div>
                            </div>

          <div className="flex justify-center space-x-3 mt-4">
                <button
                  type="button"
                  onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500"
                >
                  Cancel
                </button>
                <button
              type="button"
              onClick={onConfirm}
              className={`px-4 py-2 text-sm font-medium text-white rounded-md focus:outline-none focus:ring-2 focus:ring-offset-2 ${
                newStatus
                  ? 'bg-green-600 hover:bg-green-700 focus:ring-green-500'
                  : 'bg-red-600 hover:bg-red-700 focus:ring-red-500'
              }`}
            >
              {newStatus ? 'Activate User' : 'Deactivate User'}
                </button>
              </div>
        </div>
      </div>
    </div>
  );
}

// User Activities Section Component
function UserActivitiesSection({ activities, loading }) {
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-aqua-500"></div>
      </div>
    );
  }

  const activityTypes = {
    fish_predictions: { title: 'Fish Prediction', color: 'blue' },
    water_calculations: { title: 'Water Calculation', color: 'cyan' },
    fish_calculations: { title: 'Fish Capacity', color: 'green' },
    diet_calculations: { title: 'Diet Calculation', color: 'orange' },
    fish_volume_calculations: { title: 'Volume Calculation', color: 'purple' },
    compatibility_results: { title: 'Compatibility Check', color: 'pink' },
    tanks: { title: 'Tank Management', color: 'indigo' }
  };

  // Combine all activities with timestamps
  const allActivities = [];
  
  Object.entries(activities).forEach(([type, data]) => {
    if (Array.isArray(data)) {
      data.forEach((item, index) => {
        const timestamp = item.created_at || item.date_calculated || new Date().toISOString();
        allActivities.push({
          type,
          data: item,
          timestamp: new Date(timestamp),
          id: `${type}-${index}`
        });
      });
    }
  });

  // Sort by timestamp (newest first)
  allActivities.sort((a, b) => b.timestamp - a.timestamp);

  const getActivityDescription = (activity) => {
    const { type, data } = activity;
    
    switch (type) {
      case 'fish_predictions':
        const fishName = data.predicted_fish || data.common_name || data.species_name || 'Unknown fish';
        return `Fish: ${fishName}`;
      case 'water_calculations':
        const fishSelections = data.fish_selections || {};
        const fishNames = Object.keys(fishSelections);
        const fishList = fishNames.length > 0 ? fishNames.slice(0, 3).join(', ') : 'No fish selected';
        const moreFish = fishNames.length > 3 ? ` +${fishNames.length - 3} more` : '';
        const recommendedQuantities = data.recommended_quantities || {};
        const quantitiesList = Object.keys(recommendedQuantities).length > 0 
          ? Object.entries(recommendedQuantities).slice(0, 3).map(([fish, qty]) => `${fish}: ${qty}`).join(', ')
          : 'No quantities';
        const moreQuantities = Object.keys(recommendedQuantities).length > 3 ? ` +${Object.keys(recommendedQuantities).length - 3} more` : '';
        const minVolume = data.minimum_tank_volume || data.total_volume || data.min_volume || 'N/A';
        return `Fish: ${fishList}${moreFish} • Recommended quantities: ${quantitiesList}${moreQuantities} • Min tank volume: ${minVolume}`;
      case 'fish_calculations':
        const tankShape = data.tank_shape || data.calculation_type || data.shape || 'tank';
        const tankVolume = data.tank_volume || data.calculated_volume || data.volume || 'N/A';
        const fishSelectionsCalc = data.fish_selections || {};
        const fishListCalc = Object.keys(fishSelectionsCalc).slice(0, 2).join(', ');
        const moreFishCalc = Object.keys(fishSelectionsCalc).length > 2 ? ` +${Object.keys(fishSelectionsCalc).length - 2} more` : '';
        return `Tank: ${tankShape} (${tankVolume}), Fish: ${fishListCalc || 'None'}${moreFishCalc}`;
      case 'diet_calculations':
        const totalPortion = data.total_portion || data.total_feed || 'N/A';
        const fishSelectionsDiet = data.fish_selections || {};
        const fishListDiet = Object.keys(fishSelectionsDiet).length > 0 
          ? Object.entries(fishSelectionsDiet).slice(0, 2).map(([fish, qty]) => `${fish}(${qty})`).join(', ')
          : 'None';
        const moreFishDiet = Object.keys(fishSelectionsDiet).length > 2 ? ` +${Object.keys(fishSelectionsDiet).length - 2} more` : '';
        return `Fish: ${fishListDiet}${moreFishDiet}, Total: ${totalPortion}g`;
      case 'fish_volume_calculations':
        const shape = data.shape || data.tank_shape || 'tank';
        const volume = data.calculated_volume || data.volume || data.tank_volume || 'N/A';
        const fishSelectionsVol = data.fish_selections || {};
        const fishListVol = Object.keys(fishSelectionsVol).slice(0, 2).join(', ');
        const moreFishVol = Object.keys(fishSelectionsVol).length > 2 ? ` +${Object.keys(fishSelectionsVol).length - 2} more` : '';
        return `Tank: ${shape} (${volume}L), Fish: ${fishListVol || 'None'}${moreFishVol}`;
      case 'compatibility_results':
        let selectedFish = 'Unknown fish';
        if (data.selected_fish) {
          if (typeof data.selected_fish === 'object') {
            // If it's an object, extract the keys (fish names)
            selectedFish = Object.keys(data.selected_fish).join(', ');
          } else if (typeof data.selected_fish === 'string') {
            selectedFish = data.selected_fish;
          }
        }
        const compatibilityLevel = data.compatibility_level || 'Unknown';
        return `Selected fish: ${selectedFish} • Compatibility level: ${compatibilityLevel}`;
      case 'tanks':
        const tankName = data.name || 'Unnamed tank';
        const tankShapeTank = data.tank_shape || 'rectangle';
        const length = data.length || 'N/A';
        const width = data.width || 'N/A';
        const height = data.height || 'N/A';
        const unit = data.unit || 'cm';
        const volumeTank = data.volume || 'N/A';
        const fishSelectionsTank = data.fish_selections || {};
        const fishCountTank = typeof fishSelectionsTank === 'object' ? Object.keys(fishSelectionsTank).length : 0;
        const availableFeeds = data.available_feeds || {};
        const feedNames = typeof availableFeeds === 'object' ? Object.keys(availableFeeds) : [];
        const feedList = feedNames.length > 0 
          ? feedNames.slice(0, 3).map(feed => `${feed}(${availableFeeds[feed]}g)`).join(', ')
          : 'None';
        const moreFeeds = feedNames.length > 3 ? ` +${feedNames.length - 3} more` : '';
        return `Tank name: ${tankName} • Tank shape: ${tankShapeTank} • Tank dimensions: ${length}×${width}×${height}${unit} • Tank volume: ${volumeTank}L • Fish count: ${fishCountTank} • Feeds: ${feedList}${moreFeeds}`;
      default:
        return 'Activity performed';
    }
  };

  const getColorClasses = (color) => {
    const colorMap = {
      blue: 'bg-blue-100 text-blue-800 border-blue-200',
      cyan: 'bg-cyan-100 text-cyan-800 border-cyan-200',
      green: 'bg-green-100 text-green-800 border-green-200',
      orange: 'bg-orange-100 text-orange-800 border-orange-200',
      purple: 'bg-purple-100 text-purple-800 border-purple-200',
      pink: 'bg-pink-100 text-pink-800 border-pink-200',
      indigo: 'bg-indigo-100 text-indigo-800 border-indigo-200'
    };
    return colorMap[color] || 'bg-gray-100 text-gray-800 border-gray-200';
  };

  return (
    <div className="space-y-6">
      <div className="text-center mb-6">
        <h4 className="text-lg font-medium text-gray-900">Recent Activity Timeline</h4>
        <p className="text-sm text-gray-500">Chronological view of user's app activities</p>
      </div>

      {allActivities.length === 0 ? (
        <div className="text-center text-gray-500 py-12">
          <div className="text-4xl mb-4">📝</div>
          <p className="text-lg font-medium">No activities found</p>
          <p className="text-sm">This user hasn't performed any activities yet.</p>
        </div>
      ) : (
        <div className="bg-white border border-gray-200 rounded-lg overflow-hidden">
          <div className="max-h-96 overflow-y-auto">
            <div className="divide-y divide-gray-200">
              {allActivities.slice(0, 50).map((activity, index) => {
                const activityType = activityTypes[activity.type] || { title: 'Activity', color: 'gray' };
                const isLast = index === allActivities.slice(0, 50).length - 1;
                
                return (
                  <div key={activity.id} className="relative p-4 hover:bg-gray-50 transition-colors">
                    {/* Timeline line */}
                    {!isLast && (
                      <div className="absolute left-4 top-12 w-0.5 h-full bg-gray-200"></div>
                    )}
                    
                    <div className="flex items-start space-x-4">
                      {/* Activity indicator dot */}
                      <div className={`flex-shrink-0 w-3 h-3 rounded-full mt-1 ${getColorClasses(activityType.color).split(' ')[0]}`}></div>
                      
                      {/* Content */}
                      <div className="flex-1 min-w-0">
                        <div className="flex items-center justify-between">
                          <h5 className="text-sm font-medium text-gray-900">
                            {activityType.title}
                          </h5>
                          <time className="text-xs text-gray-500">
                            {format(activity.timestamp, 'MMM dd, yyyy HH:mm')}
                          </time>
                        </div>
                        
                        <p className="mt-1 text-sm text-gray-600">
                          {getActivityDescription(activity)}
                        </p>
                        
                        {/* Additional details */}
                        <div className="mt-2 flex flex-wrap gap-2">
                          {activity.type === 'fish_predictions' && activity.data.confidence && (
                            <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                              Confidence: {Math.round(activity.data.confidence * 100)}%
                            </span>
                          )}
                          {activity.type === 'compatibility_results' && activity.data.compatibility_score && (
                            <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-pink-100 text-pink-800">
                              Score: {activity.data.compatibility_score}
                            </span>
                          )}
                          {activity.type === 'diet_calculations' && activity.data.feeding_frequency && (
                            <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                              {activity.data.feeding_frequency}x daily
                            </span>
                          )}
                          {activity.type === 'tanks' && activity.data.water_type && (
                            <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-indigo-100 text-indigo-800">
                              {activity.data.water_type}
                            </span>
                          )}
                          {activity.type === 'fish_calculations' && activity.data.capacity_result && (
                            <span className="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              Capacity: {activity.data.capacity_result}
                            </span>
                          )}
                        </div>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
          
          {allActivities.length > 50 && (
            <div className="px-4 py-3 bg-gray-50 border-t border-gray-200 text-center">
              <p className="text-sm text-gray-500">
                Showing 50 of {allActivities.length} activities
              </p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default UserManagement;



