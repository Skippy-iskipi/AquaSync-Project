import axios from 'axios';

// Create an axios instance with default config
const api = axios.create({
  baseURL: '/api/admin', // This will be proxied to http://localhost:8080/api/admin
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 30000, // 30 second timeout
});

// Add request interceptor to add auth token
api.interceptors.request.use((config) => {
  // Log the request URL for debugging
  console.log('Making API request to:', {
    url: config.url,
    baseURL: config.baseURL,
    fullPath: `${config.baseURL}${config.url}`
  });
  
  const token = localStorage.getItem('admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  } else {
    console.warn('No admin token found in localStorage');
  }
  return config;
}, (error) => {
  console.error('Request interceptor error:', error);
  return Promise.reject({
    message: 'Failed to make request',
    error: error.message
  });
});

// Add response interceptor for better error handling
api.interceptors.response.use((response) => {
  console.log('Received API response:', {
    url: response.config.url,
    status: response.status,
    data: response.data
  });
  return response;
}, (error) => {
  console.error('API Error:', {
    message: error.message,
    code: error.code,
    status: error.response?.status,
    data: error.response?.data,
    url: error.config?.url,
    baseURL: error.config?.baseURL,
    fullPath: `${error.config?.baseURL}${error.config?.url}`
  });

  if (error.code === 'ECONNABORTED') {
    return Promise.reject({
      message: 'The request took too long to complete. Please try again.',
      code: 'TIMEOUT'
    });
  }

  if (!error.response) {
    return Promise.reject({
      message: 'Cannot connect to the server. Please check your connection.',
      code: 'NETWORK_ERROR'
    });
  }

  if (error.response.status === 401) {
    localStorage.removeItem('admin_token');
    window.location.href = '/login';
    return Promise.reject({
      message: 'Your session has expired. Please log in again.',
      code: 'UNAUTHORIZED'
    });
  }

  if (error.response.status === 403) {
    return Promise.reject({
      message: 'You do not have permission to perform this action.',
      code: 'FORBIDDEN'
    });
  }

  if (error.response.status === 404) {
    return Promise.reject({
      message: `Resource not found: ${error.config?.url}`,
      code: 'NOT_FOUND'
    });
  }

  return Promise.reject({
    message: error.response?.data?.message || 'An unexpected error occurred',
    code: error.response?.status || 'UNKNOWN'
  });
});

const userApi = {
  getAllUsers: async () => {
    try {
      console.log('Fetching all users...');
      const response = await api.get('/users');
      console.log('Users fetched successfully:', response.data?.length || 0);
      return response.data.map(user => ({
        ...user,
        key: user.id,
        status: user.user?.confirmed_at ? 'active' : 'pending',
        lastSignIn: user.user?.last_sign_in_at ? new Date(user.user.last_sign_in_at) : null
      }));
    } catch (error) {
      console.error('Error in getAllUsers:', error);
      throw error;
    }
  },

  getUser: async (id) => {
    try {
      const response = await api.get(`/users/${id}`);
      return {
        ...response.data,
        status: response.data.user?.confirmed_at ? 'active' : 'pending',
        lastSignIn: response.data.user?.last_sign_in_at ? new Date(response.data.user.last_sign_in_at) : null
      };
    } catch (error) {
      console.error('Error in getUser:', error);
      throw error;
    }
  },

  createUser: async (userData) => {
    try {
      const response = await api.post('/users', userData);
      return response.data;
    } catch (error) {
      console.error('Error in createUser:', error);
      throw error;
    }
  },

  updateUser: async (id, userData) => {
    try {
      const response = await api.put(`/users/${id}`, userData);
      return response.data;
    } catch (error) {
      console.error('Error in updateUser:', error);
      throw error;
    }
  },

  deleteUser: async (id) => {
    try {
      const response = await api.delete(`/users/${id}`);
      return response.data;
    } catch (error) {
      console.error('Error in deleteUser:', error);
      throw error;
    }
  }
};

export default userApi;