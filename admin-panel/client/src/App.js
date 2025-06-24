import React, { useState } from 'react';
import { createBrowserRouter, RouterProvider, Navigate, Outlet, useNavigate } from 'react-router-dom';
import './index.css';

// Pages
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import FishManagement from './pages/FishManagement';
import ArchivedFish from './pages/ArchivedFish';

// Components
import AppLayout from './components/Layout';

// Auth context
import { useAuth } from './utils/AuthContext';

// Error Component
const ErrorPage = () => {
  return (
    <div style={{ 
      display: 'flex', 
      flexDirection: 'column', 
      alignItems: 'center', 
      justifyContent: 'center', 
      height: '100vh',
      padding: '20px',
      textAlign: 'center'
    }}>
      <h1>Oops!</h1>
      <p>Sorry, an unexpected error has occurred.</p>
      <button 
        onClick={() => window.location.href = '/'}
        style={{
          padding: '10px 20px',
          marginTop: '20px',
          border: 'none',
          borderRadius: '5px',
          backgroundColor: '#1890ff',
          color: 'white',
          cursor: 'pointer'
        }}
      >
        Go to Dashboard
      </button>
    </div>
  );
};

const ProtectedLayout = () => {
  const { isAuthenticated, user, loading, logout } = useAuth();
  const [showModal, setShowModal] = useState(false);
  const navigate = useNavigate();

  if (loading) return null; // or a spinner

  const role = user?.app_metadata?.role;
  if (!isAuthenticated) {
    return <Navigate to="/login" />;
  }
  if (role !== 'admin') {
    // Show modal and redirect on close
    if (!showModal) setShowModal(true);

    return (
      <>
        {showModal && (
          <div style={{
            position: 'fixed',
            top: 0, left: 0, right: 0, bottom: 0,
            background: 'rgba(0,0,0,0.3)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 9999
          }}>
            <div style={{
              background: 'white',
              padding: '2rem',
              borderRadius: '8px',
              boxShadow: '0 2px 8px rgba(0,0,0,0.2)',
              textAlign: 'center'
            }}>
              <h2>Access Denied</h2>
              <p>You do not have permission to access this page.</p>
              <button
                onClick={async () => {
                  setShowModal(false);
                  await logout();
                  navigate('/login', { replace: true });
                }}
                style={{
                  padding: '10px 20px',
                  marginTop: '20px',
                  border: 'none',
                  borderRadius: '5px',
                  backgroundColor: '#1890ff',
                  color: 'white',
                  cursor: 'pointer'
                }}
              >
                OK
              </button>
            </div>
          </div>
        )}
      </>
    );
  }

  return (
    <AppLayout>
      <Outlet />
    </AppLayout>
  );
};

const router = createBrowserRouter([
  {
    path: '/login',
    element: <Login />,
    errorElement: <ErrorPage />
  },
  {
    path: '/',
    element: <ProtectedLayout />,
    errorElement: <ErrorPage />,
    children: [
      {
        path: '',
        element: <Dashboard />
      },
      {
        path: 'fish',
        element: <FishManagement />
      },
      {
        path: 'fish/archived',
        element: <ArchivedFish />
      },
      {
        path: '*',
        element: <Navigate to="/" replace />
      }
    ]
  }
], {
  future: {
    v7_startTransition: true,
    v7_relativeSplatPath: true
  }
});

const App = () => {
  return <RouterProvider router={router} />;
};

export default App; 