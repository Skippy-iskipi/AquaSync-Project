import React, { createContext, useContext, useState, useEffect, useCallback } from 'react';
import { supabase } from './supabase';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  const checkAdminAccess = async (userId) => {
    try {
      console.log('Checking admin access for user:', userId);
      
      // First check admin_users table
      const { data: adminUser, error: adminError } = await supabase
        .from('admin_users')
        .select('*')
        .eq('id', userId)
        .single();

      if (adminError) {
        console.error('Error checking admin_users:', adminError);
      }

      if (adminUser) {
        console.log('User found in admin_users table');
        return true;
      }

      // Then check profiles table for super_admin role
      const { data: profile, error: profileError } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .single();

      if (profileError) {
        console.error('Error checking profiles:', profileError);
        return false;
      }

      console.log('Profile role:', profile?.role);
      return profile?.role === 'super_admin' || profile?.role === 'admin';

    } catch (error) {
      console.error('Error in checkAdminAccess:', error);
      return false;
    }
  };

  const handleSession = useCallback(async (session) => {
    console.log('Handling session:', session);
    
    if (session?.user) {
      const isAdmin = await checkAdminAccess(session.user.id);
      console.log('Is admin?', isAdmin);

      if (isAdmin) {
        setIsAuthenticated(true);
        setUser(session.user);
        localStorage.setItem('admin_token', session.access_token);
        console.log('Admin session established');
      } else {
        console.log('User is not an admin');
        setIsAuthenticated(false);
        setUser(null);
        localStorage.removeItem('admin_token');
        await supabase.auth.signOut();
      }
    } else {
      console.log('No session found');
      setIsAuthenticated(false);
      setUser(null);
      localStorage.removeItem('admin_token');
    }
  }, []);

  useEffect(() => {
    console.log('AuthProvider mounted');
    
    // Check for active session on mount
    supabase.auth.getSession().then(({ data: { session }, error }) => {
      if (error) {
        console.error('Error getting session:', error);
        setLoading(false);
        return;
      }
      handleSession(session).finally(() => setLoading(false));
    });

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, session) => {
      console.log('Auth state changed:', _event);
      await handleSession(session);
    });

    return () => {
      console.log('Cleaning up auth subscription');
      subscription?.unsubscribe();
    };
  }, [handleSession]);

  const login = async (email, password) => {
    try {
      console.log('Attempting login for:', email);
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password
      });
      
      if (error) {
        console.error('Login error:', error);
        throw error;
      }

      console.log('Login successful, checking admin access');
      const isAdmin = await checkAdminAccess(data.user.id);
      
      if (!isAdmin) {
        console.log('User is not an admin, signing out');
        await supabase.auth.signOut();
        throw new Error('Access denied. Admin privileges required.');
      }

      console.log('Admin login successful');
      setIsAuthenticated(true);
      setUser(data.user);
      localStorage.setItem('admin_token', data.session.access_token);
      return { success: true };
    } catch (error) {
      console.error('Login process error:', error);
      setIsAuthenticated(false);
      setUser(null);
      localStorage.removeItem('admin_token');
      return { success: false, error: error.message };
    }
  };

  const logout = async () => {
    try {
      console.log('Logging out');
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
      
      setIsAuthenticated(false);
      setUser(null);
      localStorage.removeItem('admin_token');
      console.log('Logout successful');
      return { success: true };
    } catch (error) {
      console.error('Logout error:', error);
      return { success: false, error: error.message };
    }
  };

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <AuthContext.Provider value={{ 
      isAuthenticated, 
      user, 
      loading, 
      login, 
      logout,
      getToken: () => localStorage.getItem('admin_token')
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};