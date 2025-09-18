import React, { useState, useEffect } from 'react';
import { 
  PlusIcon, 
  PencilIcon, 
  TrashIcon, 
  MagnifyingGlassIcon,
  EyeIcon
} from '@heroicons/react/24/outline';
import { format } from 'date-fns';
import toast from 'react-hot-toast';
import DeleteConfirmDialog from '../components/DeleteConfirmDialog';

// Error boundary component for tank rendering
class TankErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('Tank rendering error:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="text-red-600 font-medium">Error displaying tank data</div>
          <div className="text-red-500 text-sm mt-1">Please try refreshing the page</div>
        </div>
      );
    }

    return this.props.children;
  }
}

// Helper function to safely format numbers with 2 decimal places
const formatNumber = (num) => {
  try {
    // Handle null, undefined, or empty values
    if (num === null || num === undefined || num === '') return 'N/A';
    
    // Convert string numbers to actual numbers
    const parsedNum = typeof num === 'string' ? parseFloat(num) : num;
    
    // Check if it's a valid number
    if (typeof parsedNum !== 'number' || isNaN(parsedNum) || !isFinite(parsedNum)) return 'N/A';
    
    return parsedNum.toFixed(2);
  } catch (error) {
    console.warn('Error formatting number:', num, error);
    return 'N/A';
  }
};

// Helper function to get authentication token
const getAuthToken = () => {
  const token = localStorage.getItem('admin_token');
  if (!token || token === 'null' || token === 'undefined') {
    console.error('No valid authentication token found');
    toast.error('Authentication required. Please log in again.');
    return null;
  }
  return token;
};

// Helper component to display key-value pairs in a clean format
const InfoRow = ({ label, value, unit = '', className = '' }) => (
  <div className={`flex justify-between py-1 ${className}`}>
    <span className="text-sm font-medium text-gray-600">{label}:</span>
    <span className="text-sm text-gray-900 font-medium">
      {value !== null && value !== undefined ? `${value} ${unit}` : 'N/A'}
    </span>
  </div>
);

// Helper component to display fish information in a clean format
const FishInfo = ({ fish, index }) => {
  if (!fish) return null;
  
  return (
    <div key={index} className="bg-gray-50 p-3 rounded-lg border border-gray-200 mb-3">
      <h6 className="font-medium text-gray-800 mb-2">{fish.species || 'Unknown Fish'}</h6>
      <div className="grid grid-cols-2 gap-2 text-sm">
        {fish.quantity && <InfoRow label="Quantity" value={fish.quantity} />}
        {fish.portion_grams && <InfoRow label="Portion per fish" value={fish.portion_grams} unit="g" />}
        {fish.diet && <InfoRow label="Diet" value={fish.diet} />}
        {fish.preferred_food && <InfoRow label="Preferred Food" value={fish.preferred_food} />}
      </div>
    </div>
  );
};

// Helper component to display feed inventory items
const FeedItem = ({ feed, index }) => {
  if (!feed) return null;
  
  return (
    <div key={index} className="bg-gray-50 p-3 rounded-lg border border-gray-200 mb-3">
      <h6 className="font-medium text-gray-800 mb-2">{feed.feed_type || 'Feed'}</h6>
      <div className="grid grid-cols-2 gap-2 text-sm">
        {feed.quantity && <InfoRow label="Quantity" value={feed.quantity} unit="g" />}
        {feed.days_remaining && <InfoRow label="Days Remaining" value={feed.days_remaining} />}
        {feed.last_updated && (
          <InfoRow 
            label="Last Updated" 
            value={format(new Date(feed.last_updated), 'MMM dd, yyyy')} 
            className="col-span-2"
          />
        )}
      </div>
    </div>
  );
};

function UserManagement() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUser, setSelectedUser] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [modalMode, setModalMode] = useState('view');
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [userToDelete, setUserToDelete] = useState(null);

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
      console.log('Fetched users data:', data);
      console.log('Number of users:', Array.isArray(data) ? data.length : 0);
      
      // Log each user's role to debug admin filtering
      if (Array.isArray(data)) {
        data.forEach(user => {
          console.log(`User: ${user.email}, Role: ${user.role}, Active: ${user.active}`);
        });
      }
      
      setUsers(Array.isArray(data) ? data : []);
    } catch (error) {
      toast.error('Failed to fetch users data');
      console.error('Error fetching users:', error);
      setUsers([]); // Ensure users is always an array
    } finally {
      setLoading(false);
    }
  };

  const handleViewUser = async (userData) => {
    try {
      const token = getAuthToken();
      if (!token) return;
      
      // Fetch user's tanks data
      const response = await fetch(`/api/users/${userData.id}/tanks`, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (response.status === 401) {
        toast.error('Authentication expired. Please log in again.');
        return;
      }
      
      const tanksData = await response.json();
      
      setSelectedUser({
        ...userData,
        tanks: tanksData
      });
      setModalMode('view');
      setShowModal(true);
    } catch (error) {
      console.error('Error fetching user tanks:', error);
      toast.error('Failed to fetch user tank data');
      // Still show modal with user data only
      setSelectedUser({
        ...userData,
        tanks: []
      });
      setModalMode('view');
      setShowModal(true);
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

  const handleDeleteUser = (userId) => {
    setUserToDelete(userId);
    setShowDeleteDialog(true);
  };

  const confirmDeleteUser = async () => {
    if (!userToDelete) return;
    
    try {
      const token = getAuthToken();
      if (!token) return;
      
      const response = await fetch(`/api/users/${userToDelete}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      
      if (response.status === 401) {
        toast.error('Authentication expired. Please log in again.');
        return;
      }
      
      if (response.ok) {
        toast.success('User deleted successfully');
        console.log('User deleted successfully, refreshing user list...');
        await fetchUsers();
        console.log('User list refreshed');
      } else {
        const errorData = await response.json();
        console.error('Delete Error:', errorData);
        toast.error(`Failed to delete user: ${errorData.message || 'Unknown error'}`);
      }
    } catch (error) {
      toast.error('Error deleting user');
      console.error('Error:', error);
    } finally {
      setShowDeleteDialog(false);
      setUserToDelete(null);
    }
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
      
      console.log('Sending user data:', cleanedData);
      
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
        console.error('Bad Request Error:', errorData);
        if (errorData.errors && errorData.errors.length > 0) {
          console.error('Validation errors:', errorData.errors);
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
        console.error('Save Error:', errorData);
        toast.error(`Failed to ${modalMode === 'add' ? 'create' : 'update'} user: ${errorData.message || 'Unknown error'}`);
      }
    } catch (error) {
      toast.error(`Error ${modalMode === 'add' ? 'creating' : 'updating'} user`);
      console.error('Error:', error);
    }
  };

  const handleToggleUserStatus = async (userId, currentStatus) => {
    try {
      const newStatus = !currentStatus;
      const token = getAuthToken();
      if (!token) return;
      
      const response = await fetch(`/api/users/${userId}/status`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ active: newStatus }),
      });

      if (response.status === 401) {
        toast.error('Authentication expired. Please log in again.');
        return;
      }

      if (response.ok) {
        toast.success(`User ${newStatus ? 'activated' : 'deactivated'} successfully`);
        fetchUsers();
      } else {
        toast.error('Failed to update user status');
      }
    } catch (error) {
      toast.error('Error updating user status');
      console.error('Error:', error);
    }
  };

  const filteredUsers = users.filter(user => {
    // Hide admin users from frontend
    // Check multiple possible admin indicators
    const isAdmin = user.role === 'admin' || 
                   user.email === 'admin@aquasync.com' ||
                   (user.email && user.email.toLowerCase().includes('admin'));
    
    if (isAdmin) {
      console.log('Filtering out admin user:', user.email, 'role:', user.role);
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

      {/* Users Table */}
      <div className="bg-white shadow overflow-hidden sm:rounded-md">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="table-header">Email</th>
              <th className="table-header">Role</th>
              <th className="table-header">Created</th>
              <th className="table-header">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {currentItems.map((user) => (
              <tr key={user.id} className="hover:bg-gray-50">
                <td className="table-cell">
                  {user.email || 'N/A'}
                </td>
                <td className="table-cell">
                  <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                    user.role === 'admin' 
                      ? 'bg-purple-100 text-purple-800'
                      : user.role === 'premium'
                      ? 'bg-yellow-100 text-yellow-800'
                      : 'bg-gray-100 text-gray-800'
                  }`}>
                    {user.role || 'user'}
                  </span>
                </td>
                <td className="table-cell">
                  <div className="text-sm text-gray-500">
                    {user.updated_at ? format(new Date(user.updated_at), 'MMM dd, yyyy') : 'N/A'}
                  </div>
                </td>
                <td className="table-cell">
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
                      onClick={() => handleEditUser(user)}
                      className="text-indigo-600 hover:text-indigo-900"
                      title="Edit User"
                    >
                      <PencilIcon className="h-4 w-4" />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleDeleteUser(user.id)}
                      className="text-red-600 hover:text-red-900"
                      title="Delete User"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
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
        />
      )}

      {/* Delete Confirmation Dialog */}
      <DeleteConfirmDialog
        isOpen={showDeleteDialog}
        onClose={() => setShowDeleteDialog(false)}
        onConfirm={confirmDeleteUser}
        title="Delete User"
        message="Are you sure you want to delete this user? This action cannot be undone."
        confirmText="Delete User"
        cancelText="Cancel"
      />
    </div>
  );
}

function UserModal({ user, mode, onSave, onClose }) {
  const [formData, setFormData] = useState(user);
  const [activeTab, setActiveTab] = useState('profile');
  const [expandedTanks, setExpandedTanks] = useState({});

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

  const toggleTankExpansion = (tankIndex) => {
    setExpandedTanks(prev => ({
      ...prev,
      [tankIndex]: !prev[tankIndex]
    }));
  };

  const isReadOnly = mode === 'view';

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-20 mx-auto p-5 border w-11/12 max-w-6xl shadow-lg rounded-md bg-white">
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

          {/* Tabs for Profile and Tanks */}
          {isReadOnly && (
            <div className="border-b border-gray-200 mb-6">
              <nav className="-mb-px flex space-x-8">
                <button
                  type="button"
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
                  type="button"
                  onClick={() => setActiveTab('tanks')}
                  className={`py-2 px-1 border-b-2 font-medium text-sm ${
                    activeTab === 'tanks'
                      ? 'border-aqua-500 text-aqua-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  Tank Information ({formData.tanks?.length || 0})
                </button>
              </nav>
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Profile Information Tab */}
            {(!isReadOnly || activeTab === 'profile') && (
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

                </>
              )}
            </div>
            )}

            {/* Tank Information Tab */}
            {isReadOnly && activeTab === 'tanks' && (
              <div className="space-y-6">
                {formData.tanks && formData.tanks.length > 0 ? (
                  <TankErrorBoundary>
                    <div className="space-y-4">
                      {formData.tanks.map((tank, index) => {
                      // Safety check to ensure tank is a valid object
                      if (!tank || typeof tank !== 'object') {
                        return (
                          <div key={index} className="bg-gray-50 rounded-lg border p-4">
                            <div className="text-red-600">Invalid tank data</div>
                          </div>
                        );
                      }
                      
                      return (
                      <div key={index} className="bg-gray-50 rounded-lg border">
                        <div className="flex items-center justify-between p-4">
                          <h4 className="text-lg font-medium text-gray-900">
                            {tank.name || `Tank ${index + 1}`}
                          </h4>
                          <div className="flex items-center space-x-4">
                            <span className="text-sm text-gray-500">
                              Created: {tank.created_at ? format(new Date(tank.created_at), 'MMM dd, yyyy') : 'N/A'}
                            </span>
                            <button
                              type="button"
                              onClick={() => toggleTankExpansion(index)}
                              className="px-3 py-1 text-sm bg-aqua-600 text-white rounded hover:bg-aqua-700 transition-colors"
                            >
                              {expandedTanks[index] ? 'Collapse' : 'Expand'}
                            </button>
                          </div>
                        </div>
                        
                        {expandedTanks[index] && (
                          <div className="px-6 pb-6">
                            {/* Tank Details - Simplified Layout */}
                            <div className="space-y-6">
                              {/* Tank Dimensions */}
                              <div className="bg-white rounded-lg p-4 border">
                                <h5 className="text-lg font-semibold text-gray-800 mb-3">
                                  Tank Dimensions
                                </h5>
                                <div className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-4">
                                  <div className="bg-gray-50 p-3 rounded-lg">
                                    <div className="text-xs text-gray-500 uppercase tracking-wide">Shape</div>
                                    <div className="text-sm font-medium text-gray-900 mt-1">{tank.tank_shape || 'N/A'}</div>
                                  </div>
                                  <div className="bg-gray-50 p-3 rounded-lg">
                                    <div className="text-xs text-gray-500 uppercase tracking-wide">Length</div>
                                    <div className="text-sm font-medium text-gray-900 mt-1">{tank.length || 'N/A'} {tank.unit || ''}</div>
                                  </div>
                                  <div className="bg-gray-50 p-3 rounded-lg">
                                    <div className="text-xs text-gray-500 uppercase tracking-wide">Width</div>
                                    <div className="text-sm font-medium text-gray-900 mt-1">{tank.width || 'N/A'} {tank.unit || ''}</div>
                                  </div>
                                  <div className="bg-gray-50 p-3 rounded-lg">
                                    <div className="text-xs text-gray-500 uppercase tracking-wide">Height</div>
                                    <div className="text-sm font-medium text-gray-900 mt-1">{tank.height || 'N/A'} {tank.unit || ''}</div>
                                  </div>
                                  <div className="bg-gray-50 p-3 rounded-lg">
                                    <div className="text-xs text-gray-600 uppercase tracking-wide font-medium">Volume</div>
                                    <div className="text-sm font-bold text-gray-700 mt-1">{tank.volume || 'N/A'} L</div>
                                  </div>
                                </div>
                              </div>

                              {/* Fish Selections & Compatibility */}
                              <div className="bg-white rounded-lg p-4 border">
                                <h5 className="text-lg font-semibold text-gray-800 mb-3">
                                  Fish & Compatibility
                                </h5>
                                <div className="space-y-4">
                                  {/* Fish Selections */}
                                  {tank.fish_selections && (
                                    <div>
                                      <div className="text-sm font-medium text-gray-700 mb-2">Fish Selections</div>
                                      <div className="bg-gray-50 p-3 rounded-lg border border-gray-200">
                                        <div className="space-y-2">
                                          {typeof tank.fish_selections === 'object' && tank.fish_selections !== null ? (
                                            Object.entries(tank.fish_selections).map(([species, quantity]) => (
                                              <div key={species} className="flex justify-between items-center bg-white p-2 rounded border">
                                                <span className="font-medium text-gray-700">{species}</span>
                                                <span className="bg-gray-100 text-gray-800 text-xs font-medium px-2.5 py-0.5 rounded">
                                                  {quantity} {quantity === 1 ? 'fish' : 'fish'}
                                                </span>
                                              </div>
                                            ))
                                          ) : (
                                            <p className="text-sm text-gray-500">No fish selected</p>
                                          )}
                                        </div>
                                      </div>
                                    </div>
                                  )}

                                  {/* Compatibility Results */}
                                  {tank.compatibility_results && (
                                    <div>
                                      <div className="text-sm font-medium text-gray-700 mb-2">Compatibility Results</div>
                                      <div className="bg-gray-50 p-3 rounded-lg border border-gray-200">
                                        <div className="space-y-2">
                                          {tank.compatibility_results ? (
                                            <div className="space-y-2">
                                              {tank.compatibility_results.issues && tank.compatibility_results.issues.length > 0 ? (
                                                <div className="text-sm text-gray-600">
                                                  <div className="font-medium mb-1">Compatibility Issues:</div>
                                                  <ul className="list-disc pl-5 space-y-1">
                                                    {tank.compatibility_results.issues.map((issue, idx) => (
                                                      <li key={idx}>{issue}</li>
                                                    ))}
                                                  </ul>
                                                </div>
                                              ) : (
                                                <div className="text-sm text-gray-700">
                                                  ✓ All fish are compatible
                                                </div>
                                              )}
                                              {tank.compatibility_results.notes && (
                                                <div className="text-sm text-gray-600 mt-2">
                                                  <div className="font-medium">Notes:</div>
                                                  <p>{tank.compatibility_results.notes}</p>
                                                </div>
                                              )}
                                            </div>
                                          ) : (
                                            <p className="text-sm text-gray-500">No compatibility data available</p>
                                          )}
                                        </div>
                                      </div>
                                    </div>
                                  )}
                                </div>
                              </div>

                              {/* Feed Inventory */}
                              <div className="bg-white rounded-lg p-4 border">
                                <h5 className="text-lg font-semibold text-gray-800 mb-3">
                                  Feed Inventory
                                </h5>
                                <div className="space-y-4">
                                  {/* Available Feeds */}
                                  {tank.available_feeds && typeof tank.available_feeds === 'object' && (
                                    <div>
                                      <div className="text-sm font-medium text-gray-700 mb-2">Available Feeds</div>
                                      <div className="bg-gray-50 p-3 rounded-lg border border-gray-200">
                                        <div className="space-y-2">
                                          {Object.keys(tank.available_feeds || {}).length > 0 ? (
                                            <div className="grid gap-2">
                                              {Object.entries(tank.available_feeds || {}).map(([feedType, amount]) => (
                                                <div key={feedType} className="bg-gray-50 p-3 rounded border border-gray-100">
                                                  <div className="font-medium">{feedType}</div>
                                                  <div className="text-sm text-gray-700">
                                                    {formatNumber(amount)} {typeof amount === 'number' ? 'grams' : ''} available
                                                  </div>
                                                </div>
                                              ))}
                                            </div>
                                          ) : (
                                            <p className="text-sm text-gray-500">No feed types available</p>
                                          )}
                                        </div>
                                      </div>
                                    </div>
                                  )}

                                  {/* Feed Inventory with Days Left */}
                                  {tank.feed_inventory && typeof tank.feed_inventory === 'object' && (
                                    <div>
                                      <div className="text-sm font-medium text-gray-700 mb-2">Feed Inventory Status</div>
                                      <div className="bg-gray-50 p-3 rounded-lg border border-gray-200">
                                        <div className="space-y-3">
                                          {Object.keys(tank.feed_inventory || {}).length > 0 ? (
                                            <div className="space-y-3">
                                              {Object.entries(tank.feed_inventory || {}).map(([feedName, feedData]) => {
                                                // Handle different possible field names for days remaining
                                                const daysRemaining = feedData?.days_remaining ?? 
                                                                     feedData?.days_until_empty ?? 
                                                                     feedData?.days_left ?? 
                                                                     null;
                                                
                                                // Handle different possible field names for available amount
                                                const availableAmount = feedData?.available_grams ?? 
                                                                       feedData?.available_amount ?? 
                                                                       feedData?.quantity ?? 
                                                                       null;
                                                
                                                // Handle different possible field names for last updated
                                                const lastUpdated = feedData?.last_updated ?? 
                                                                   feedData?.updated_at ?? 
                                                                   feedData?.last_modified ?? 
                                                                   null;
                                                
                                                return (
                                                  <div key={feedName} className="bg-white p-4 rounded-lg border border-gray-200">
                                                    <div className="flex justify-between items-start">
                                                      <h6 className="font-medium text-gray-800">{feedName}</h6>
                                                      <span className={`px-2 py-1 text-xs font-medium rounded ${
                                                        daysRemaining === null || daysRemaining === undefined
                                                          ? 'bg-gray-100 text-gray-800'
                                                          : daysRemaining <= 0 
                                                            ? 'bg-gray-200 text-gray-600'
                                                            : daysRemaining <= 7
                                                              ? 'bg-gray-200 text-gray-700'
                                                              : 'bg-gray-100 text-gray-800'
                                                      }`}>
                                                        {daysRemaining === null || daysRemaining === undefined
                                                          ? 'In Stock' 
                                                          : daysRemaining <= 0 
                                                            ? 'Out of Stock' 
                                                            : `${daysRemaining} days left`}
                                                      </span>
                                                    </div>
                                                    
                                                    <div className="mt-2 grid grid-cols-2 gap-2">
                                                      <div>
                                                        <p className="text-xs text-gray-500">Available Amount</p>
                                                        <p className="font-medium">
                                                          {availableAmount !== null && availableAmount !== undefined 
                                                            ? `${formatNumber(availableAmount)} ${feedData?.unit || 'g'}`
                                                            : 'N/A'}
                                                        </p>
                                                      </div>
                                                      <div>
                                                        <p className="text-xs text-gray-500">Daily Consumption</p>
                                                        <p className="font-medium">
                                                          {feedData?.daily_consumption !== null && feedData?.daily_consumption !== undefined 
                                                            ? `${formatNumber(feedData.daily_consumption)} g/day`
                                                            : 'N/A'}
                                                        </p>
                                                      </div>
                                                    </div>
                                                    
                                                    {/* Fish Consumption Breakdown */}
                                                    {feedData?.fish_consumption && typeof feedData.fish_consumption === 'object' && Object.keys(feedData.fish_consumption).length > 0 && (
                                                      <div className="mt-3 pt-3 border-t border-gray-200">
                                                        <p className="text-xs text-gray-500 mb-2">Fish Consumption Breakdown</p>
                                                        <div className="space-y-1">
                                                          {Object.entries(feedData.fish_consumption).map(([fishName, consumption]) => (
                                                            <div key={fishName} className="flex justify-between items-center text-sm">
                                                              <span className="text-gray-600">{fishName}:</span>
                                                              <span className="font-medium text-gray-900">
                                                                {formatNumber(consumption)} g/day
                                                              </span>
                                                            </div>
                                                          ))}
                                                        </div>
                                                      </div>
                                                    )}
                                                  </div>
                                                );
                                              })}
                                            </div>
                                          ) : (
                                            <p className="text-sm text-gray-500">No feed inventory data available</p>
                                          )}
                                        </div>
                                      </div>
                                    </div>
                                  )}
                                </div>
                              </div>
                            </div>

                            {/* Timestamps */}
                            <div className="mt-4 pt-4 border-t border-gray-200">
                              <div className="flex justify-between text-xs text-gray-500">
                                <span>Date Created: {tank.date_created ? format(new Date(tank.date_created), 'PPpp') : 'N/A'}</span>
                                <span>Last Updated: {tank.last_updated ? format(new Date(tank.last_updated), 'PPpp') : 'N/A'}</span>
                              </div>
                            </div>
                          </div>
                        )}
                      </div>
                      );
                    })}
                    </div>
                  </TankErrorBoundary>
                ) : (
                  <div className="text-center py-8 text-gray-500">
                    <div className="text-lg font-medium">No Tanks Found</div>
                    <div className="text-sm">This user hasn't created any tanks yet.</div>
                  </div>
                )}
              </div>
            )}

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
        </div>
      </div>
    </div>
  );
}

export default UserManagement;



