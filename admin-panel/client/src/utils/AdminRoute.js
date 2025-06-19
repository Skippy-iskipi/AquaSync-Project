import { useAuth } from '../utils/AuthContext';
import { Navigate } from 'react-router-dom';

const AdminRoute = ({ children }) => {
  const { user, loading } = useAuth();
  if (loading) return null; // or a spinner

  // Check for admin role in app_metadata
  const role = user?.app_metadata?.role;
  if (!user || role !== 'admin') {
    return <Navigate to="/login" />;
  }
  return children;
};

export default AdminRoute;
