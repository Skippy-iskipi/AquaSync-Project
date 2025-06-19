import React, { useState } from 'react';
import { Layout, Menu, Button, Avatar, Dropdown, Space, Drawer, Grid } from 'antd';
import {
  DashboardOutlined,
  ExperimentOutlined,
  LogoutOutlined,
  UserOutlined,
  InboxOutlined,
  FileOutlined,
  PictureOutlined,
  MenuOutlined
} from '@ant-design/icons';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../utils/AuthContext';

const { Header, Sider, Content } = Layout;
const { useBreakpoint } = Grid;

const AppLayout = ({ children }) => {
  const [drawerOpen, setDrawerOpen] = useState(false);
  const { logout, user } = useAuth();
  const location = useLocation();
  const navigate = useNavigate();
  const screens = useBreakpoint();

  const handleLogout = () => {
    logout();
    navigate('/login');
  };

  const userMenuItems = [
    {
      key: 'logout',
      icon: <LogoutOutlined />,
      label: 'Logout',
      onClick: handleLogout
    }
  ];

  const menuItems = [
    {
      key: '/',
      icon: <DashboardOutlined />,
      label: <Link to="/">Dashboard</Link>
    },
    {
      key: '/fish',
      icon: <ExperimentOutlined />,
      label: 'Fish Management',
      children: [
        {
          key: '/fish',
          icon: <FileOutlined />,
          label: <Link to="/fish">Active Fish</Link>
        },
        {
          key: '/fish/archived',
          icon: <InboxOutlined />,
          label: <Link to="/fish/archived">Archived Fish</Link>
        }
      ]
    },
    {
      key: '/fish-images',
      icon: <PictureOutlined />,
      label: <Link to="/fish-images">Fish Images</Link>
    }
  ];

  return (
    <Layout style={{ minHeight: '100vh' }}>
      {/* Sider only on desktop */}
      {screens.md && (
        <Sider
          style={{
            background: '#006064',
          }}
        >
          <div style={{
            height: '64px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: 'white',
            fontSize: '20px',
            fontWeight: 'bold',
            margin: '16px 0'
          }}>
            AquaSync Admin
          </div>
          <Menu
            theme="dark"
            mode="inline"
            selectedKeys={[location.pathname]}
            items={menuItems}
            style={{
              background: '#006064',
            }}
          />
        </Sider>
      )}
      <Layout>
        <Header
          style={{
            padding: 0,
            background: '#fff',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
          }}
        >
          {/* Left side: burger menu (mobile only) or empty (desktop) */}
          <div>
            {!screens.md && (
              <Button
                type="text"
                icon={<MenuOutlined />}
                onClick={() => setDrawerOpen(true)}
                style={{ fontSize: '20px', marginLeft: 8 }}
                className="md:hidden"
              />
            )}
          </div>
          {/* Right side: user avatar */}
          <div>
            <Dropdown menu={{ items: userMenuItems }} placement="bottomRight">
              <Space style={{ cursor: 'pointer', marginRight: 16 }}>
                <Avatar icon={<UserOutlined />} />
                {user?.username}
              </Space>
            </Dropdown>
          </div>
        </Header>
        {/* Drawer for mobile navigation */}
        <Drawer
          title="Menu"
          placement="left"
          onClose={() => setDrawerOpen(false)}
          open={drawerOpen}
          bodyStyle={{ padding: 0 }}
          className="md:hidden"
        >
          <Menu
            mode="inline"
            selectedKeys={[location.pathname]}
            items={menuItems}
            onClick={() => setDrawerOpen(false)}
          />
        </Drawer>
        <Content style={{ margin: '24px 16px', padding: 24, background: '#fff' }}>
          {children}
        </Content>
      </Layout>
    </Layout>
  );
};

export default AppLayout; 