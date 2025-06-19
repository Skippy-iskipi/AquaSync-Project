import React, { useState, useEffect } from 'react';
import {
  Card,
  Row,
  Col,
  Typography,
  Spin,
  Statistic,
  message,
} from 'antd';
import {
  DatabaseOutlined
} from '@ant-design/icons';
import { PieChart, Pie, Cell, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { supabase } from '../utils/supabase';

const { Title } = Typography;

// Colors for charts
const COLORS = ['#0088FE', '#00C49F', '#FFBB28', '#FF8042', '#8884d8'];

const Dashboard = () => {
  const [dashboardData, setDashboardData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [fishSpeciesData, setFishSpeciesData] = useState([]);
  const [waterTypeData, setWaterTypeData] = useState([]);

  useEffect(() => {
    fetchDashboardData();
    fetchFishSpeciesData();
  }, []);

  const fetchFishSpeciesData = async () => {
    try {
      // Fetch all fish species from Supabase
      const { data, error } = await supabase.from('fish_species').select('*');
      if (error) throw error;
      if (Array.isArray(data)) {
        setFishSpeciesData(data);
        // Calculate water type statistics
        const waterTypeStats = {};
        data.forEach(fish => {
          const waterType = fish.water_type || 'Unknown';
          waterTypeStats[waterType] = (waterTypeStats[waterType] || 0) + 1;
        });
        // Convert to format needed for the pie chart
        const waterTypeChartData = Object.entries(waterTypeStats).map(([type, count]) => ({
          name: type,
          value: count
        }));
        setWaterTypeData(waterTypeChartData);
      }
    } catch (error) {
      console.error('Error fetching fish species data:', error);
      message.error('Failed to fetch fish species data');
    }
  };

  const fetchDashboardData = async () => {
    try {
      const { data } = await supabase.from('admin_activity').select('*');
      setDashboardData(data);
    } catch (error) {
      console.error('Error fetching dashboard data:', error);
      message.error('Failed to load dashboard data');
    } finally {
      setLoading(false);
    }
  };



  // Prepare data for water type pie chart using directly fetched fish species data
  const getWaterTypePieData = () => {
    if (waterTypeData.length > 0) {
      return waterTypeData;
    }
    
    // Fallback to dashboard data if direct fetch failed
    if (!dashboardData?.statistics?.waterTypeStats) return [];
    return dashboardData.statistics.waterTypeStats.map(stat => ({
      name: stat.type || 'Unknown',
      value: stat.count
    }));
  };


  if (loading) {
    return (
      <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '80vh' }}>
        <Spin size="large" tip="Loading dashboard data..." />
      </div>
    );
  }

  return (
    <div className="dashboard-container">
      <Title level={2}>Dashboard</Title>
      <Row gutter={[16, 16]}>
        <Col xs={24} sm={24} md={24} lg={24}>
          <Card style={{ height: '300px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Statistic
              title="Total Fish Species"
              value={fishSpeciesData.length || dashboardData?.statistics?.totalFish || 0}
              prefix={<DatabaseOutlined />}
              valueStyle={{ color: '#3f8600' }}
            />
          </Card>
        </Col>
        <Col xs={24} sm={24} md={24} lg={24}>
          <Card title="Fish by Water Type" style={{ height: '300px' }}>
            {getWaterTypePieData().length > 0 ? (
              <ResponsiveContainer width="100%" height={250}>
                <PieChart>
                  <Pie
                    data={getWaterTypePieData()}
                    cx="50%"
                    cy="50%"
                    labelLine={true}
                    outerRadius={60}
                    fill="#8884d8"
                    dataKey="value"
                    label={({name, percent}) => `${name}: ${(percent * 100).toFixed(0)}%`}
                  >
                    {getWaterTypePieData().map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip formatter={(value) => [value, 'Count']} />
                  <Legend />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100%' }}>
                No data available
              </div>
            )}
          </Card>
        </Col>
      </Row>
    </div>
  );
};

export default Dashboard;