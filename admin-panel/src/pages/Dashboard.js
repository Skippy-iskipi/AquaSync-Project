import React, { useState, useEffect } from 'react';
import { 
  UsersIcon, 
  BeakerIcon, 
  ChartBarIcon
} from '@heroicons/react/24/outline';

function Dashboard() {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalFish: 0,
    totalTanks: 0
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const fetchDashboardData = async () => {
    try {
      setLoading(true);

      const token = localStorage.getItem('admin_token');
      if (!token || token === 'null' || token === 'undefined') {
        console.error('No valid authentication token found');
        setLoading(false);
        return;
      }
      
      const headers = {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      };

      const statsRes = await fetch('/api/dashboard/stats', { headers });
      
      const statsData = statsRes.ok ? await statsRes.json() : { 
        totalUsers: 0, 
        totalFish: 0, 
        totalTanks: 0
      };

      setStats(statsData);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      setStats({ 
        totalUsers: 0, 
        totalFish: 0, 
        totalTanks: 0
      });
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
    </div>
  );
}

export default Dashboard;