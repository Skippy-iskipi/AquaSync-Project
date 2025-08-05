import React, { useState, useEffect } from 'react';
import {
  Table,
  Button,
  Modal,
  Form,
  Input,
  Space,
  Popconfirm,
  message,
  Tag
} from 'antd';
import userApi from '../utils/userApi';

const UserManagement = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [editingUser, setEditingUser] = useState(null);
  const [form] = Form.useForm();

  // Fetch users on component mount
  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const data = await userApi.getAllUsers();
      setUsers(data || []);
    } catch (error) {
      message.error(error.message || 'Failed to fetch users');
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCreate = () => {
    setEditingUser(null);
    form.resetFields();
    setModalVisible(true);
  };

  const handleEdit = (record) => {
    setEditingUser(record);
    form.setFieldsValue({
      email: record.user?.email,
      full_name: record.full_name,
      username: record.username,
    });
    setModalVisible(true);
  };

  const handleDelete = async (userId) => {
    try {
      await userApi.deleteUser(userId);
      message.success('User deleted successfully');
      fetchUsers();
    } catch (error) {
      message.error(error.message || 'Failed to delete user');
      console.error('Error deleting user:', error);
    }
  };

  const handleModalOk = async () => {
    try {
      const values = await form.validateFields();
      
      if (editingUser) {
        await userApi.updateUser(editingUser.id, values);
        message.success('User updated successfully');
      } else {
        await userApi.createUser(values);
        message.success('User created successfully');
      }
      
      setModalVisible(false);
      form.resetFields();
      fetchUsers();
    } catch (error) {
      if (!error.errorFields) {
        message.error(error.message || 'Failed to save user');
      }
    }
  };

  const columns = [
    {
      title: 'Email',
      dataIndex: ['user', 'email'],
      key: 'email',
      sorter: (a, b) => (a.user?.email || '').localeCompare(b.user?.email || ''),
      render: (email) => email || '-'
    },
    {
      title: 'Full Name',
      dataIndex: 'full_name',
      key: 'full_name',
      sorter: (a, b) => (a.full_name || '').localeCompare(b.full_name || ''),
      render: (name) => name || '-'
    },
    {
      title: 'Username',
      dataIndex: 'username',
      key: 'username',
      sorter: (a, b) => (a.username || '').localeCompare(b.username || ''),
      render: (username) => username || '-'
    },
    {
      title: 'Status',
      key: 'status',
      render: (_, record) => (
        <Tag color={record.user?.confirmed_at ? 'green' : 'orange'}>
          {record.user?.confirmed_at ? 'Verified' : 'Pending'}
        </Tag>
      ),
      filters: [
        { text: 'Verified', value: 'verified' },
        { text: 'Pending', value: 'pending' }
      ],
      onFilter: (value, record) => 
        value === 'verified' ? !!record.user?.confirmed_at : !record.user?.confirmed_at
    },
    {
      title: 'Last Sign In',
      key: 'last_sign_in',
      render: (_, record) => 
        record.user?.last_sign_in_at ? 
        new Date(record.user.last_sign_in_at).toLocaleString() : 
        'Never',
      sorter: (a, b) => {
        const dateA = a.user?.last_sign_in_at ? new Date(a.user.last_sign_in_at) : new Date(0);
        const dateB = b.user?.last_sign_in_at ? new Date(b.user.last_sign_in_at) : new Date(0);
        return dateA - dateB;
      }
    },
    {
      title: 'Actions',
      key: 'actions',
      render: (_, record) => (
        <Space>
          <Button type="link" onClick={() => handleEdit(record)}>
            Edit
          </Button>
          <Popconfirm
            title="Delete User"
            description="Are you sure you want to delete this user? This action cannot be undone."
            onConfirm={() => handleDelete(record.id)}
            okText="Yes"
            cancelText="No"
            okButtonProps={{ danger: true }}
          >
            <Button type="link" danger>
              Delete
            </Button>
          </Popconfirm>
        </Space>
      )
    }
  ];

  return (
    <div className="p-6">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-semibold">User Management</h1>
        <Button type="primary" onClick={handleCreate}>
          Create User
        </Button>
      </div>

      <Table
        columns={columns}
        dataSource={users}
        rowKey="id"
        loading={loading}
        pagination={{
          defaultPageSize: 10,
          showSizeChanger: true,
          showQuickJumper: true,
          showTotal: (total) => `Total ${total} users`
        }}
      />

      <Modal
        title={editingUser ? 'Edit User' : 'Create User'}
        open={modalVisible}
        onOk={handleModalOk}
        onCancel={() => {
          setModalVisible(false);
          form.resetFields();
        }}
        styles={{
          body: {
            paddingTop: 24,
          },
        }}
      >
        <Form
          form={form}
          layout="vertical"
        >
          <Form.Item
            name="email"
            label="Email"
            rules={[
              { required: true, message: 'Please input email' },
              { type: 'email', message: 'Please enter a valid email' }
            ]}
          >
            <Input placeholder="Email" />
          </Form.Item>

          {!editingUser && (
            <Form.Item
              name="password"
              label="Password"
              rules={[
                { required: !editingUser, message: 'Please input password' },
                { min: 6, message: 'Password must be at least 6 characters' }
              ]}
            >
              <Input.Password placeholder="Password" />
            </Form.Item>
          )}

          <Form.Item
            name="full_name"
            label="Full Name"
            rules={[{ required: true, message: 'Please input full name' }]}
          >
            <Input placeholder="Full Name" />
          </Form.Item>

          <Form.Item
            name="username"
            label="Username"
            rules={[
              { required: true, message: 'Please input username' },
              { min: 3, message: 'Username must be at least 3 characters' }
            ]}
          >
            <Input placeholder="Username" />
          </Form.Item>
        </Form>
      </Modal>
    </div>
  );
};

export default UserManagement;