import React, { useState, useEffect } from 'react';
import { supabase } from '../utils/supabase';
import { 
  Table, 
  Button, 
  Modal, 
  Form, 
  Input, 
  Select, 
  InputNumber, 
  message, 
  Popconfirm,
  Spin,
  Typography,
  Space,
  Tag,
  Tooltip
} from 'antd';
import { 
  EditOutlined, 
  InboxOutlined, 
  SearchOutlined,
  ExclamationCircleOutlined
} from '@ant-design/icons';

const { Title } = Typography;
const { Option } = Select;
const { TextArea } = Input;

// Configure axios with defaults
// axios.defaults.baseURL = 'http://localhost:8080';

// Add authentication token to all requests
// axios.interceptors.request.use(
//   config => {
//     const token = localStorage.getItem('token');
//     if (token) {
//       config.headers['Authorization'] = `Bearer ${token}`;
//     }
//     return config;
//   },
//   error => Promise.reject(error)
// );

const FishManagement = () => {
  const [fishList, setFishList] = useState([]);
  const [loading, setLoading] = useState(false);
  const [modalVisible, setModalVisible] = useState(false);
  const [modalTitle, setModalTitle] = useState('Add New Fish');
  const [editingFish, setEditingFish] = useState(null);
  const [form] = Form.useForm();
  const [searchText, setSearchText] = useState('');
  const [filteredFishList, setFilteredFishList] = useState([]);

  useEffect(() => {
    fetchFishList();
  }, []);

  useEffect(() => {
    if (searchText) {
      const filtered = fishList.filter(fish => 
        fish.common_name.toLowerCase().includes(searchText.toLowerCase()) || 
        fish.scientific_name.toLowerCase().includes(searchText.toLowerCase())
      );
      setFilteredFishList(filtered);
    } else {
      setFilteredFishList(fishList);
    }
  }, [searchText, fishList]);

  const fetchFishList = async () => {
    setLoading(true);
    try {
      // Fetch all fish from Supabase where status is 'active'
      const { data, error } = await supabase.from('fish_species').select('*').eq('status', 'active');
      if (error) throw error;
      setFishList(data || []);
      setFilteredFishList(data || []);
    } catch (error) {
      console.error('Error fetching fish list:', error);
      message.error('Failed to fetch fish list');
    } finally {
      setLoading(false);
    }
  };

  const handleFormSubmit = async (values) => {
    try {
      setLoading(true);
      
      // Transform the values to match database column names
      const transformedValues = {
        common_name: values.common_name,
        scientific_name: values.scientific_name,
        water_type: values.water_type,
        "max_size_(cm)": values.max_size,
        temperament: values.temperament,
        "temperature_range_(°c)": values.temperature_range,
        ph_range: values.ph_range,
        habitat_type: values.habitat_type,
        social_behavior: values.social_behavior,
        tank_level: values.tank_level,
        "minimum_tank_size_(l)": values.minimum_tank_size,
        compatibility_notes: values.compatibility_notes,
        diet: values.diet,
        lifespan: values.lifespan,
        care_level: values.care_level,
        preferred_food: values.preferred_food,
        feeding_frequency: values.feeding_frequency
      };
      
      console.log('Sending data:', transformedValues);
      
      if (editingFish) {
        const response = await supabase.from('fish_species').update(transformedValues).eq('id', editingFish.id);
        console.log('Update response:', response);
        message.success('Fish updated successfully');
      } else {
        const response = await supabase.from('fish_species').insert(transformedValues);
        console.log('Add response:', response);
        message.success('Fish added successfully');
      }
      
      setModalVisible(false);
      form.resetFields();
      setEditingFish(null);
      fetchFishList();
    } catch (error) {
      console.error('Error saving fish:', error);
      message.error('Failed to save fish data');
    } finally {
      setLoading(false);
    }
  };

  const handleArchive = async (id) => {
    try {
      setLoading(true);
      // Using a PATCH request to update the status to 'archived'
      const response = await supabase.from('fish_species').update({ status: 'archived' }).eq('id', id);
      console.log('Archive response:', response);
      message.success('Fish archived successfully');
      fetchFishList();
    } catch (error) {
      console.error('Error archiving fish:', error);
      message.error('Failed to archive fish');
    } finally {
      setLoading(false);
    }
  };

  const showAddModal = () => {
    setModalTitle('Add New Fish');
    setEditingFish(null);
    form.resetFields();
    setModalVisible(true);
  };

  const showEditModal = (fish) => {
    setModalTitle('Edit Fish');
    setEditingFish(fish);
    
    form.setFieldsValue({
      common_name: fish.common_name,
      scientific_name: fish.scientific_name,
      water_type: fish.water_type,
      max_size: fish["max_size_(cm)"],
      temperament: fish.temperament,
      temperature_range: fish["temperature_range_(°c)"],
      ph_range: fish.ph_range,
      habitat_type: fish.habitat_type,
      social_behavior: fish.social_behavior,
      tank_level: fish.tank_level,
      minimum_tank_size: fish["minimum_tank_size_(l)"],
      compatibility_notes: fish.compatibility_notes,
      diet: fish.diet,
      lifespan: fish.lifespan,
      care_level: fish.care_level,
      preferred_food: fish.preferred_food,
      feeding_frequency: fish.feeding_frequency
    });
    
    setModalVisible(true);
  };

  const columns = [
    {
      title: 'Common Name',
      dataIndex: 'common_name',
      key: 'common_name',
      sorter: (a, b) => a.common_name.localeCompare(b.common_name),
    },
    {
      title: 'Scientific Name',
      dataIndex: 'scientific_name',
      key: 'scientific_name',
      sorter: (a, b) => a.scientific_name.localeCompare(b.scientific_name),
      render: (text) => <span style={{ fontStyle: 'italic' }}>{text}</span>,
    },
    {
      title: 'Water Type',
      dataIndex: 'water_type',
      key: 'water_type',
      filters: [
        { text: 'Freshwater', value: 'Freshwater' },
        { text: 'Saltwater', value: 'Saltwater' },
      ],
      onFilter: (value, record) => record.water_type === value,
      render: (text) => {
        let color = 'blue';
        if (text === 'Saltwater') color = 'geekblue';
        return <Tag color={color}>{text}</Tag>;
      },
    },
    {
      title: 'Max Size (cm)',
      dataIndex: 'max_size_(cm)',
      key: 'max_size_(cm)',
      sorter: (a, b) => (a["max_size_(cm)"] || 0) - (b["max_size_(cm)"] || 0),
      render: (text) => text || '-',
    },
    {
      title: 'Temperament',
      dataIndex: 'temperament',
      key: 'temperament',
      filters: [
        { text: 'Peaceful', value: 'Peaceful' },
        { text: 'Semi-aggressive', value: 'Semi-aggressive' },
        { text: 'Aggressive', value: 'Aggressive' },
      ],
      onFilter: (value, record) => record.temperament === value,
      render: (text) => {
        let color = 'green';
        if (text === 'Semi-aggressive') color = 'orange';
        if (text === 'Aggressive') color = 'red';
        return <Tag color={color}>{text}</Tag>;
      },
    },
    {
      title: 'Temperature (°C)',
      dataIndex: 'temperature_range_(°c)',
      key: 'temperature_range_(°c)',
      render: (text) => text || '-',
    },
    {
      title: 'pH Range',
      dataIndex: 'ph_range',
      key: 'ph_range',
      render: (text) => text || '-',
    },
    {
      title: 'Min Tank (L)',
      dataIndex: 'minimum_tank_size_(l)',
      key: 'minimum_tank_size_(l)',
      sorter: (a, b) => (a["minimum_tank_size_(l)"] || 0) - (b["minimum_tank_size_(l)"] || 0),
      render: (text) => text || '-',
    },
    {
      title: 'Actions',
      key: 'actions',
      width: 150,
      render: (_, record) => (
        <Space>
          <Tooltip title="Edit">
            <Button 
              icon={<EditOutlined />} 
              onClick={() => showEditModal(record)} 
              type="primary" 
              size="small"
            />
          </Tooltip>
          <Tooltip title="Move to Archive">
            <Popconfirm
              title="Are you sure you want to archive this fish?"
              onConfirm={() => handleArchive(record.id)}
              okText="Yes"
              cancelText="No"
              icon={<ExclamationCircleOutlined style={{ color: 'red' }} />}
            >
              <Button 
                icon={<InboxOutlined />} 
                type="primary" 
                danger 
                size="small"
              />
            </Popconfirm>
          </Tooltip>
        </Space>
      ),
    },
  ];

  return (
    <div className="fish-management">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between mb-4 gap-2">
        <Title level={3} className="!mb-0 text-left md:text-left">Fish Management</Title>
        <div className="flex flex-col sm:flex-row gap-2 w-full md:w-auto items-center">
          <Input
            placeholder="Search fish"
            prefix={<SearchOutlined />}
            value={searchText}
            onChange={e => setSearchText(e.target.value)}
            className="w-full sm:w-48"
          />
          <Button
            type="primary"
            onClick={showAddModal}
            className="w-full sm:w-auto flex items-center justify-center"
          >
            Add Fish
          </Button>

        </div>
      </div>

      <Spin spinning={loading}>
        <Table 
          dataSource={filteredFishList} 
          columns={columns} 
          rowKey="id"
          scroll={{ x: 'max-content' }}
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            pageSizeOptions: ['10', '20', '50'],
          }}
          className="w-full"
        />
      </Spin>

      <Modal
        title={modalTitle}
        open={modalVisible}
        onCancel={() => {
          setModalVisible(false);
          form.resetFields();
        }}
        footer={null}
        width={800}
        className="!p-2"
      >
        <Form
          form={form}
          layout="vertical"
          onFinish={handleFormSubmit}
        >
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1">
              <Form.Item
                name="common_name"
                label="Common Name"
                rules={[{ required: true, message: 'Please enter common name' }]}
              >
                <Input placeholder="Common Name" />
              </Form.Item>

              <Form.Item
                name="scientific_name"
                label="Scientific Name"
                rules={[{ required: true, message: 'Please enter scientific name' }]}
              >
                <Input placeholder="Scientific Name" />
              </Form.Item>

              <Form.Item
                name="water_type"
                label="Water Type"
                rules={[{ required: true, message: 'Please select water type' }]}
              >
                <Select placeholder="Select water type">
                  <Option value="Freshwater">Freshwater</Option>
                  <Option value="Saltwater">Saltwater</Option>
                </Select>
              </Form.Item>

              <Form.Item
                name="max_size"
                label="Maximum Size (cm)"
                rules={[{ required: true, message: 'Please enter maximum size' }]}
              >
                <InputNumber 
                  min={0} 
                  step={0.1} 
                  precision={1}
                  style={{ width: '100%' }} 
                  placeholder="e.g., 23.5"
                />
              </Form.Item>

              <Form.Item
                name="temperament"
                label="Temperament"
                rules={[{ required: true, message: 'Please select temperament' }]}
              >
                <Select placeholder="Select temperament">
                  <Option value="Peaceful">Peaceful</Option>
                  <Option value="Semi-aggressive">Semi-aggressive</Option>
                  <Option value="Aggressive">Aggressive</Option>
                </Select>
              </Form.Item>

              <Form.Item
                name="temperature_range"
                label="Temperature Range"
                rules={[{ required: true, message: 'Please enter temperature range' }]}
              >
                <Input placeholder="e.g., 24-28" />
              </Form.Item>

              <Form.Item
                name="ph_range"
                label="pH Range"
                rules={[{ required: true, message: 'Please enter pH range' }]}
              >
                <Input placeholder="e.g., 6.5-7.5" />
              </Form.Item>
            </div>

            <div className="flex-1">
              <Form.Item
                name="habitat_type"
                label="Habitat Type"
              >
                <Input placeholder="Habitat Type" />
              </Form.Item>

              <Form.Item
                name="social_behavior"
                label="Social Behavior"
              >
                <Select placeholder="Select social behavior">
                  <Option value="Solitary">Solitary</Option>
                  <Option value="Pair">Pair</Option>
                  <Option value="School">School</Option>
                  <Option value="Community">Community</Option>
                </Select>
              </Form.Item>

              <Form.Item
                name="tank_level"
                label="Tank Level"
              >
                <Select placeholder="Select tank level">
                  <Option value="Top">Top</Option>
                  <Option value="Middle">Middle</Option>
                  <Option value="Bottom">Bottom</Option>
                  <Option value="All levels">All levels</Option>
                </Select>
              </Form.Item>

              <Form.Item
                name="minimum_tank_size"
                label="Minimum Tank Size (liters)"
              >
                <InputNumber 
                  min={0} 
                  step={0.1}
                  precision={1}
                  style={{ width: '100%' }} 
                  placeholder="e.g., 60.5"
                />
              </Form.Item>

              <Form.Item
                name="diet"
                label="Diet"
              >
                <Select placeholder="Select diet">
                  <Option value="Carnivore">Carnivore</Option>
                  <Option value="Herbivore">Herbivore</Option>
                  <Option value="Omnivore">Omnivore</Option>
                </Select>
              </Form.Item>

              <Form.Item
                name="preferred_food"
                label="Preferred Food"
              >
                <Input placeholder="Preferred Food" />
              </Form.Item>

              <Form.Item
                name="feeding_frequency"
                label="Feeding Frequency"
              >
                <Input placeholder="e.g., 2-3 times daily" />
              </Form.Item>
            </div>
          </div>

          <Form.Item
            name="compatibility_notes"
            label="Compatibility Notes"
          >
            <TextArea
              placeholder="Add any compatibility notes here"
              autoSize={{ minRows: 3, maxRows: 6 }}
            />
          </Form.Item>

          <Form.Item
            name="care_level"
            label="Care Level"
          >
            <Select placeholder="Select care level">
              <Option value="Easy">Easy</Option>
              <Option value="Moderate">Moderate</Option>
              <Option value="Difficult">Difficult</Option>
              <Option value="Expert">Expert</Option>
            </Select>
          </Form.Item>

          <Form.Item
            name="lifespan"
            label="Lifespan"
          >
            <Input placeholder="e.g., 3-5 years" />
          </Form.Item>

          <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '8px' }}>
            <Button 
              onClick={() => {
                setModalVisible(false);
                form.resetFields();
              }}
            >
              Cancel
            </Button>
            <Button type="primary" htmlType="submit" loading={loading}>
              {editingFish ? 'Update' : 'Add'}
            </Button>
          </div>
        </Form>
      </Modal>
    </div>
  );
};

export default FishManagement; 