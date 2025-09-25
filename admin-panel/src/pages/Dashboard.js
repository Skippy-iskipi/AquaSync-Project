import React, { useState, useEffect } from 'react';
import { 
  UsersIcon, 
  BeakerIcon, 
  ChartBarIcon,
  BoltIcon,
  UserGroupIcon
} from '@heroicons/react/24/outline';
import { format } from 'date-fns';

function Dashboard() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalFish: 0,
    totalTanks: 0
  });
  const [recentActivities, setRecentActivities] = useState([]);
  const [userLogins, setUserLogins] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  // Helper function to get activity type information
  const getActivityTypeInfo = (activityType) => {
    const activityTypes = {
      fish_predictions: { title: 'Fish Prediction', colorClass: 'bg-blue-500' },
      water_calculations: { title: 'Water Calculation', colorClass: 'bg-cyan-500' },
      fish_calculations: { title: 'Fish Capacity', colorClass: 'bg-green-500' },
      diet_calculations: { title: 'Diet Calculation', colorClass: 'bg-orange-500' },
      fish_volume_calculations: { title: 'Volume Calculation', colorClass: 'bg-purple-500' },
      compatibility_results: { title: 'Compatibility Check', colorClass: 'bg-pink-500' },
      tanks: { title: 'Tank Management', colorClass: 'bg-indigo-500' }
    };
    return activityTypes[activityType] || { title: 'Activity', colorClass: 'bg-gray-500' };
  };

  // Helper function to get activity description (similar to UserManagement)
  const getActivityDescription = (activity) => {
    const { activity_type: type, ...data } = activity;
    
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
          ? Object.entries(fishSelectionsDiet).slice(0, 3).map(([fish, qty]) => `${fish}(${qty})`).join(', ')
          : 'None';
        const moreFishDiet = Object.keys(fishSelectionsDiet).length > 3 ? ` +${Object.keys(fishSelectionsDiet).length - 3} more` : '';
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

  const fetchDashboardData = async () => {
    try {
      setLoading(true);

      const token = localStorage.getItem('admin_token');
      if (!token || token === 'null' || token === 'undefined') {
        // No valid authentication token found
        setLoading(false);
        return;
      }
      
      const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      };

      // Fetch all data in parallel
      const [statsRes, activitiesRes, loginsRes] = await Promise.all([
        fetch('/api/dashboard/stats', { headers }),
        fetch('/api/dashboard/recent-activities?limit=10', { headers }),
        fetch('/api/dashboard/user-logins?limit=20', { headers })
      ]);
      
      const statsData = statsRes.ok ? await statsRes.json() : { 
        totalUsers: 0, 
        totalFish: 0, 
        totalTanks: 0
      };

      const activitiesData = activitiesRes.ok ? await activitiesRes.json() : [];
      const loginsData = loginsRes.ok ? await loginsRes.json() : [];

      setStats(statsData);
      setRecentActivities(activitiesData);
      setUserLogins(loginsData);
    } catch (error) {
      // Error fetching dashboard data
      setStats({ 
        totalUsers: 0, 
        totalFish: 0, 
        totalTanks: 0
      });
      setRecentActivities([]);
      setUserLogins([]);
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-gray-500"></div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="bg-gradient-to-r from-teal-50 to-blue-50 p-8 rounded-xl border border-teal-100">
        <h1 className="text-4xl font-bold text-gray-900 mb-2">Dashboard</h1>
        <p className="text-lg text-gray-600">
          Welcome to AquaSync Admin - Your comprehensive aquarium management platform
        </p>
      </div>

      {/* Key Metrics Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Users Card */}
        <div className="bg-white p-8 rounded-xl shadow-lg border border-gray-100 hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
          <div className="flex items-center justify-between mb-4">
            <div className="w-16 h-16 bg-gradient-to-br from-blue-500 to-blue-600 rounded-xl flex items-center justify-center shadow-lg">
              <UsersIcon className="h-8 w-8 text-white" />
            </div>
            <div className="text-right">
              <p className="text-sm font-medium text-gray-500 uppercase tracking-wide">Total Users</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">{stats.totalUsers?.toLocaleString() || '0'}</p>
            </div>
          </div>
          <div className="flex items-center text-sm text-gray-600">
            <div className="w-2 h-2 bg-blue-500 rounded-full mr-2"></div>
            <span>Registered users</span>
          </div>
        </div>

        {/* Fish Species Card */}
        <div className="bg-white p-8 rounded-xl shadow-lg border border-gray-100 hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
          <div className="flex items-center justify-between mb-4">
            <div className="w-16 h-16 bg-gradient-to-br from-teal-500 to-teal-600 rounded-xl flex items-center justify-center shadow-lg">
              <BeakerIcon className="h-8 w-8 text-white" />
            </div>
            <div className="text-right">
              <p className="text-sm font-medium text-gray-500 uppercase tracking-wide">Fish Species</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">{stats.totalFish?.toLocaleString() || '0'}</p>
            </div>
          </div>
          <div className="flex items-center text-sm text-gray-600">
            <div className="w-2 h-2 bg-teal-500 rounded-full mr-2"></div>
            <span>Available species</span>
          </div>
        </div>

        {/* Tanks Card */}
        <div className="bg-white p-8 rounded-xl shadow-lg border border-gray-100 hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1">
          <div className="flex items-center justify-between mb-4">
            <div className="w-16 h-16 bg-gradient-to-br from-purple-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg">
              <ChartBarIcon className="h-8 w-8 text-white" />
            </div>
            <div className="text-right">
              <p className="text-sm font-medium text-gray-500 uppercase tracking-wide">User Tanks</p>
              <p className="text-3xl font-bold text-gray-900 mt-1">{stats.totalTanks?.toLocaleString() || '0'}</p>
            </div>
          </div>
          <div className="flex items-center text-sm text-gray-600">
            <div className="w-2 h-2 bg-purple-500 rounded-full mr-2"></div>
            <span>Active tanks</span>
          </div>
        </div>
      </div>

      {/* Recent Activities Section */}
      <div className="bg-white rounded-xl shadow-lg border border-gray-100">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-gradient-to-br from-green-500 to-green-600 rounded-lg flex items-center justify-center">
              <BoltIcon className="h-6 w-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-900">User Activities</h2>
              <p className="text-sm text-gray-600">Latest user activities across the platform</p>
            </div>
          </div>
        </div>
        
        <div className="p-6">
          {recentActivities.length === 0 ? (
            <div className="text-center py-8">
              <BoltIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500">No recent activities found</p>
            </div>
          ) : (
            <div className="space-y-4">
              {recentActivities.map((activity, index) => {
                const activityType = getActivityTypeInfo(activity.activity_type);
                return (
                  <div key={index} className="flex items-start space-x-4 p-4 bg-gray-50 rounded-lg">
                    <div className={`w-3 h-3 rounded-full mt-1 ${activityType.colorClass}`}></div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between">
                        <h5 className="text-sm font-medium text-gray-900">
                          {activityType.title}
                        </h5>
                        <time className="text-xs text-gray-500">
                          {format(new Date(activity.created_at), 'MMM dd, yyyy HH:mm')}
                        </time>
                      </div>
                      <p className="text-sm text-gray-600 mt-1">
                        {getActivityDescription(activity)}
                      </p>
                      <div className="mt-2 flex items-center text-xs text-gray-500">
                        <span>User: {activity.user_email}</span>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* User Login Times Section */}
      <div className="bg-white rounded-xl shadow-lg border border-gray-100">
        <div className="p-6 border-b border-gray-200">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 bg-gradient-to-br from-purple-500 to-purple-600 rounded-lg flex items-center justify-center">
              <UserGroupIcon className="h-6 w-6 text-white" />
            </div>
            <div>
              <h2 className="text-xl font-bold text-gray-900">User Login Times</h2>
              <p className="text-sm text-gray-600">User login information and activity counts</p>
            </div>
          </div>
        </div>
        
        <div className="p-6">
          {userLogins.length === 0 ? (
            <div className="text-center py-8">
              <UserGroupIcon className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-500">No user data available</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      User
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Last Login
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Activities
                    </th>
                    <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                      Status
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {userLogins.map((user, index) => (
                    <tr key={index} className="hover:bg-gray-50">
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div>
                          <div className="text-sm font-medium text-gray-900">
                            {user.full_name || user.username || 'Unknown User'}
                          </div>
                          <div className="text-sm text-gray-500">{user.email}</div>
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">
                          {user.last_sign_in_at 
                            ? format(new Date(user.last_sign_in_at), 'MMM dd, yyyy HH:mm')
                            : 'Never'
                          }
                        </div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                          {user.total_activities} activities
                        </span>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                          user.active 
                            ? 'bg-green-100 text-green-800' 
                            : 'bg-red-100 text-red-800'
                        }`}>
                          {user.active ? 'Active' : 'Inactive'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default Dashboard;