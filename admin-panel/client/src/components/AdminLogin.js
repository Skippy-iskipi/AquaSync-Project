import React, { useState } from 'react';
import { Form, Input, Button, Card, message, Typography } from 'antd';
import { UserOutlined, LockOutlined } from '@ant-design/icons';
import { api } from '../utils/api';

const { Title } = Typography;

const AdminLogin = ({ onLoginSuccess }) => {
  const [loading, setLoading] = useState(false);

  const onFinish = async (values) => {
    try {
      setLoading(true);
      
      // For testing purposes, we'll create a simple token
      // In production, this should call your actual login endpoint
      const testToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiIxMjM0NTY3ODkwIiwiaWF0IjoxNjE2MjM5MDIyfQ.test-signature';
      
      // Store the token
      localStorage.setItem('adminToken', testToken);
      
      message.success('Login successful!');
      
      if (onLoginSuccess) {
        onLoginSuccess();
      }
      
    } catch (error) {
      console.error('Login error:', error);
      message.error('Login failed: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  const testConnection = async () => {
    try {
      setLoading(true);
      const response = await api.get('/admin/health');
      message.success('Server connection successful!');
      console.log('Health check response:', response);
    } catch (error) {
      console.error('Connection test failed:', error);
      message.error('Server connection failed: ' + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'center', 
      alignItems: 'center', 
      minHeight: '100vh',
      background: '#f0f2f5'
    }}>
      <Card style={{ width: 400 }}>
        <Title level={2} style={{ textAlign: 'center', marginBottom: 24 }}>
          Admin Login
        </Title>
        
        <Form
          name="admin_login"
          onFinish={onFinish}
          layout="vertical"
        >
          <Form.Item
            label="Username"
            name="username"
            rules={[{ required: true, message: 'Please input your username!' }]}
          >
            <Input 
              prefix={<UserOutlined />} 
              placeholder="admin"
              defaultValue="admin"
            />
          </Form.Item>

          <Form.Item
            label="Password"
            name="password"
            rules={[{ required: true, message: 'Please input your password!' }]}
          >
            <Input.Password 
              prefix={<LockOutlined />} 
              placeholder="password"
              defaultValue="password"
            />
          </Form.Item>

          <Form.Item>
            <Button 
              type="primary" 
              htmlType="submit" 
              loading={loading}
              style={{ width: '100%' }}
            >
              Login
            </Button>
          </Form.Item>
        </Form>
        
        <div style={{ textAlign: 'center', marginTop: 16 }}>
          <Button 
            type="link" 
            onClick={testConnection}
            loading={loading}
          >
            Test Server Connection
          </Button>
        </div>
        
        <div style={{ marginTop: 16, padding: 16, background: '#f6f8fa', borderRadius: 6 }}>
          <Title level={5}>Debug Info:</Title>
          <p><strong>API URL:</strong> {process.env.REACT_APP_API_URL || 'http://localhost:8080/api'}</p>
          <p><strong>Token:</strong> {localStorage.getItem('adminToken') ? 'Present' : 'Missing'}</p>
        </div>
      </Card>
    </div>
  );
};

export default AdminLogin; 