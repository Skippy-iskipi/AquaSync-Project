import React, { useState, useEffect } from 'react';
import { supabase } from '../utils/supabase';
import { 
  Table, 
  Button, 
  message, 
  Popconfirm,
  Spin,
  Typography,
  Space,
  Tag,
  Tooltip,
  Input
} from 'antd';
import { 
  UndoOutlined, 
  DeleteOutlined, 
  SearchOutlined,
  ExclamationCircleOutlined
} from '@ant-design/icons';

const { Title } = Typography;

const ArchivedFish = () => {
  const [archivedFishList, setArchivedFishList] = useState([]);
  const [loading, setLoading] = useState(false);
  const [searchText, setSearchText] = useState('');
  const [filteredFishList, setFilteredFishList] = useState([]);

  useEffect(() => {
    fetchArchivedFishList();
  }, []);

  useEffect(() => {
    if (searchText) {
      const filtered = archivedFishList.filter(fish => 
        fish.common_name.toLowerCase().includes(searchText.toLowerCase()) || 
        fish.scientific_name.toLowerCase().includes(searchText.toLowerCase())
      );
      setFilteredFishList(filtered);
    } else {
      setFilteredFishList(archivedFishList);
    }
  }, [searchText, archivedFishList]);

  const fetchArchivedFishList = async () => {
    setLoading(true);
    try {
      // Fetch all fish from Supabase where status is 'archived'
      const { data, error } = await supabase.from('fish_species').select('*').eq('status', 'archived');
      if (error) throw error;
      setArchivedFishList(data || []);
      setFilteredFishList(data || []);
    } catch (error) {
      console.error('Error fetching archived fish list:', error);
      message.error('Failed to fetch archived fish list');
    } finally {
      setLoading(false);
    }
  };

  const handleRestore = async (id) => {
    try {
      setLoading(true);
      const { error } = await supabase.from('fish_species').update({ status: 'active' }).eq('id', id);
      if (error) throw error;
      message.success('Fish restored successfully');
      fetchArchivedFishList();
    } catch (error) {
      console.error('Error restoring fish:', error);
      message.error('Failed to restore fish');
    } finally {
      setLoading(false);
    }
  };

  const handlePermanentDelete = async (id) => {
    try {
      setLoading(true);
      const { error } = await supabase.from('fish_species').delete().eq('id', id);
      if (error) throw error;
      message.success('Fish permanently deleted');
      fetchArchivedFishList();
    } catch (error) {
      console.error('Error permanently deleting fish:', error);
      message.error('Failed to permanently delete fish');
    } finally {
      setLoading(false);
    }
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
      title: 'Actions',
      key: 'actions',
      width: 150,
      render: (_, record) => (
        <Space>
          <Tooltip title="Restore">
            <Popconfirm
              title="Are you sure you want to restore this fish?"
              description="This will move the fish back to the active list."
              onConfirm={() => handleRestore(record.id)}
              okText="Yes"
              cancelText="No"
              icon={<ExclamationCircleOutlined style={{ color: 'blue' }} />}
            >
              <Button 
                icon={<UndoOutlined />} 
                type="primary" 
                size="small"
              />
            </Popconfirm>
          </Tooltip>
          <Tooltip title="Permanently Delete">
            <Popconfirm
              title="Are you sure you want to permanently delete this fish?"
              description="This action cannot be undone."
              onConfirm={() => handlePermanentDelete(record.id)}
              okText="Yes"
              cancelText="No"
              icon={<ExclamationCircleOutlined style={{ color: 'red' }} />}
            >
              <Button 
                icon={<DeleteOutlined />} 
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
    <div className="archived-fish">
      <div className="header-container" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
        <Title level={3}>Archived Fish</Title>
        <Space>
          <Input
            placeholder="Search fish"
            prefix={<SearchOutlined />}
            value={searchText}
            onChange={e => setSearchText(e.target.value)}
            style={{ width: 200 }}
          />
        </Space>
      </div>

      <Spin spinning={loading}>
        <Table 
          dataSource={filteredFishList} 
          columns={columns} 
          rowKey="id"
          pagination={{
            pageSize: 10,
            showSizeChanger: true,
            pageSizeOptions: ['10', '20', '50'],
          }}
          locale={{ emptyText: 'No archived fish found' }}
        />
      </Spin>
    </div>
  );
};

export default ArchivedFish;
