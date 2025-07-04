import React, { useState, useEffect } from 'react';
import { supabase } from '../utils/supabase';
import {
  Button,
  Form,
  Input,
  Select,
  Upload,
  message,
  Spin,
  Modal,
  Grid,
} from 'antd';
import {
  UploadOutlined,
  FolderOpenOutlined,
  EditOutlined,
  PlusOutlined,
  FolderOutlined,
} from '@ant-design/icons';
import { TrashIcon } from '@heroicons/react/24/outline';
import { useAuth } from '../utils/AuthContext';

const { Option } = Select;
const { useBreakpoint } = Grid;

const DATASET_TYPES = ['train', 'val', 'test'];

const FishImages = () => {
  const { user } = useAuth();
  const [form] = Form.useForm();
  const [editForm] = Form.useForm();
  const [uploading, setUploading] = useState(false);
  const [images, setImages] = useState([]);
  const [loading, setLoading] = useState(true);
  const [modalVisible, setModalVisible] = useState(false);
  const [editModalVisible, setEditModalVisible] = useState(false);
  const [folderModalVisible, setFolderModalVisible] = useState(false);
  const [selectedFolder, setSelectedFolder] = useState(null);
  const [editingImage, setEditingImage] = useState(null);
  const [activeTab, setActiveTab] = useState('train');
  const [previewImage, setPreviewImage] = useState(null);
  const screens = useBreakpoint();

  const fetchImages = async () => {
    setLoading(true);
    try {
      const { data, error } = await supabase.from('fish_images_dataset').select('*').order('id', { ascending: false });
      if (error) throw error;
      if (!data) {
        setImages([]);
        setLoading(false);
        return;
      }
      // For each row, get its public URL from storage
      const imageList = await Promise.all(
        data.map(async (item) => {
          let publicUrl = '';
          if (item.image_path) {
            const { data: publicUrlData } = supabase.storage.from('fish-images').getPublicUrl(item.image_path);
            publicUrl = publicUrlData.publicUrl;
          }
          return {
            ...item,
            publicUrl,
          };
        })
      );
      setImages(imageList);
    } catch (err) {
      message.error('Failed to fetch images.');
      setImages([]);
    }
    setLoading(false);
  };

  useEffect(() => {
    fetchImages();
  }, []);

  // Group images by common_name
  const groupedImages = images.reduce((acc, img) => {
    if (!acc[img.common_name]) acc[img.common_name] = [];
    acc[img.common_name].push(img);
    return acc;
  }, {});

  const handleUpload = async (values) => {
    setUploading(true);
    try {
      const { common_name, dataset, file } = values;
      const files = file && Array.isArray(file) ? file : [];
      if (!files.length) {
        message.error('Please upload at least one image file.');
        setUploading(false);
        return;
      }
      let successCount = 0;
      for (const f of files) {
        const selectedFile = f.originFileObj;
        // Use filename: <common_name>__<dataset>__<timestamp>.<ext>
        const ext = selectedFile.name.split('.').pop();
        const filename = `${common_name}__${dataset}__${Date.now()}.${ext}`;
        const path = `${user.id}/${filename}`;
        // 1. Upload to storage
        const { error: uploadError } = await supabase.storage.from('fish-images').upload(path, selectedFile, { upsert: true });
        if (uploadError) {
          message.error(`Failed to upload ${selectedFile.name}`);
          continue;
        }
        // 2. Insert metadata row
        const { error: dbError } = await supabase.from('fish_images_dataset').insert({
          common_name,
          dataset,
          image_path: path,
        });
        if (dbError) {
          message.error(`Failed to save metadata for ${selectedFile.name}`);
          // Optionally: remove the uploaded file from storage
          await supabase.storage.from('fish-images').remove([path]);
          continue;
        }
        successCount++;
      }
      if (successCount > 0) {
        message.success('Fish images added to dataset!');
        form.resetFields();
        setModalVisible(false);
        fetchImages();
      } else {
        message.error('No images were uploaded.');
      }
    } catch (err) {
      message.error('Unexpected error.');
    } finally {
      setUploading(false);
    }
  };

  // Delete image from Supabase Storage and metadata table
  const handleDelete = (img) => {
    let modalInstance = null;
    modalInstance = Modal.confirm({
      title: 'Delete Image',
      content: 'Are you sure you want to delete this image?',
      icon: null,
      centered: true,
      okButtonProps: { style: { display: 'none' } },
      cancelButtonProps: { style: { display: 'none' } },
      footer: (
        <div className="flex justify-end gap-2 mt-5">
          <button
            onClick={() => modalInstance.destroy()}
            className="px-4 py-2 rounded text-gray-700 hover:bg-gray-200 transition"
          >
            Cancel
          </button>
          <button
            onClick={async () => {
              // 1. Remove from storage
              await supabase.storage.from('fish-images').remove([img.image_path]);
              // 2. Remove from table
              await supabase.from('fish_images_dataset').delete().eq('id', img.id);
              message.success('Image deleted!');
              fetchImages();
              modalInstance.destroy();
            }}
            className="text-red-500 hover:text-red-700 hover:bg-red-500 hover:text-white p-2 rounded transition"
          >
            <TrashIcon className="w-5 h-5" />
          </button>
        </div>
      ),
    });
  };

  // Edit image (replace file and update metadata)
  const handleEdit = (img) => {
    setEditingImage(img);
    editForm.setFieldsValue({
      common_name: img.common_name,
      dataset: img.dataset,
      file: [],
    });
    setEditModalVisible(true);
  };

  const handleEditSubmit = async (values) => {
    setUploading(true);
    try {
      const { common_name, dataset, file } = values;
      let newImagePath = editingImage.image_path;
      // If a new file is uploaded, replace the old one
      const selectedFile = file && file[0] && file[0].originFileObj;
      if (selectedFile) {
        // Remove old image
        await supabase.storage.from('fish-images').remove([editingImage.image_path]);
        // Upload new image
        const ext = selectedFile.name.split('.').pop();
        const filename = `${common_name}__${dataset}__${Date.now()}.${ext}`;
        const path = `${user.id}/${filename}`;
        const { error: uploadError } = await supabase.storage.from('fish-images').upload(path, selectedFile, { upsert: true });
        if (uploadError) {
          message.error('Failed to upload new image.');
          setUploading(false);
          return;
        }
        newImagePath = path;
      }
      // Update metadata row
      const { error: dbError } = await supabase.from('fish_images_dataset').update({
        common_name,
        dataset,
        image_path: newImagePath,
      }).eq('id', editingImage.id);
      if (dbError) {
        message.error('Failed to update image metadata.');
      } else {
        message.success('Image updated!');
        setEditModalVisible(false);
        setEditingImage(null);
        fetchImages();
      }
    } catch (err) {
      message.error('Unexpected error.');
    } finally {
      setUploading(false);
    }
  };

  // Open folder modal
  const handleFolderClick = (common_name) => {
    setSelectedFolder(common_name);
    // Default to 'train' if available, else first available tab
    const folderImgs = groupedImages[common_name] || [];
    const availableTabs = DATASET_TYPES.filter(type => folderImgs.some(img => img.dataset === type));
    setActiveTab(availableTabs.includes('train') ? 'train' : (availableTabs[0] || 'train'));
    setFolderModalVisible(true);
  };

  // Responsive title size
  const getTitleSize = () => {
    if (screens.xs) return 'text-lg';
    if (screens.sm) return 'text-xl';
    return 'text-2xl';
  };

  // Filter images in modal by activeTab
  const filteredModalImages = selectedFolder && groupedImages[selectedFolder]
    ? groupedImages[selectedFolder].filter(img => img.dataset === activeTab)
    : [];

  return (
    <div className="w-full max-w-8xl mx-auto px-1 py-4">
        <div className="flex items-center justify-between mb-6 gap-2">
        <span className={`font-bold ${getTitleSize()}`}>Fish Images Dataset</span>
        <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => setModalVisible(true)}
            size="large"
            shape={screens.md ? 'default' : 'circle'}
            aria-label="Add Fish Images"
            className={`!flex items-center ${screens.md ? 'gap-2' : 'justify-center'}`}
        >
            {screens.md && 'Add Fish Images'}
        </Button>
        </div>
      {loading ? (
        <div className="flex justify-center items-center min-h-[200px]">
          <Spin tip="Loading images..." />
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
          {Object.keys(groupedImages).length === 0 && (
            <div className="col-span-full text-center">No images found.</div>
          )}
          {Object.entries(groupedImages).map(([common_name, imgs]) => (
            <div key={common_name}>
              <div
                className="bg-white rounded-lg shadow hover:shadow-lg cursor-pointer flex items-center p-4 mb-2 transition"
                onClick={() => handleFolderClick(common_name)}
              >
                <FolderOutlined className="text-3xl text-blue-500 mr-4" />
                <div className="flex-1">
                  <div className="font-semibold text-base md:text-lg">{common_name}</div>
                  <div className="text-gray-500 text-xs md:text-sm">{imgs.length} image{imgs.length !== 1 ? 's' : ''}</div>
                </div>
                <FolderOpenOutlined className="text-xl text-gray-400 ml-2" />
              </div>
            </div>
          ))}
        </div>
      )}
      {/* Add Fish Image Modal */}
      <Modal
        title="Add Fish Image"
        open={modalVisible}
        onCancel={() => setModalVisible(false)}
        footer={null}
        destroyOnClose
        centered
      >
        <Form form={form} layout="vertical" onFinish={handleUpload}>
          <Form.Item
            name="common_name"
            label="Common Name"
            rules={[{ required: true, message: 'Please enter the common name' }]}
          >
            <Input placeholder="e.g. Tilapia" />
          </Form.Item>
          <Form.Item
            name="dataset"
            label="Dataset Type"
            rules={[{ required: true, message: 'Please select a dataset type' }]}
          >
            <Select placeholder="Select dataset type">
              {DATASET_TYPES.map((type) => (
                <Option key={type} value={type}>
                  {type}
                </Option>
              ))}
            </Select>
          </Form.Item>
          <Form.Item
            name="file"
            label="Image File(s)"
            valuePropName="fileList"
            getValueFromEvent={e => Array.isArray(e) ? e : e && e.fileList}
            rules={[{ required: true, message: 'Please upload at least one image file' }]}
          >
            <Upload
              beforeUpload={() => false}
              multiple={true}
              accept="image/*"
              listType="picture"
              customRequest={() => {}}
            >
              <Button icon={<UploadOutlined />}>Select Images</Button>
            </Upload>
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={uploading} block>
              Upload & Save
            </Button>
          </Form.Item>
        </Form>
      </Modal>
      {/* Folder Images Modal */}
      <Modal
        title={selectedFolder}
        open={folderModalVisible}
        onCancel={() => { setFolderModalVisible(false); setSelectedFolder(null); }}
        footer={null}
        destroyOnClose
        centered
        width={screens.xs || screens.sm ? '85vw' : 800}
        className=""
      >
        {/* Tabs for train/val/test */}
        <div className="flex gap-2 mb-4">
          {DATASET_TYPES.filter(type => (selectedFolder && groupedImages[selectedFolder] && groupedImages[selectedFolder].some(img => img.dataset === type))).map(type => (
            <button
              key={type}
              className={`px-4 py-1 rounded-full border ${activeTab === type ? 'bg-blue-500 text-white border-blue-500' : 'bg-white text-blue-500 border-blue-500'} transition`}
              onClick={() => setActiveTab(type)}
            >
              {type}
            </button>
          ))}
        </div>
        <div className={
          'grid grid-cols-2 md:grid-cols-4 gap-4'
        }>
          {filteredModalImages.length === 0 && (
            <div className="col-span-full text-center">No images found.</div>
          )}
          {filteredModalImages.map((img) => (
            <div key={img.image_path} className="bg-white rounded-lg shadow p-2 flex flex-col">
              <img
                alt={img.common_name}
                src={img.publicUrl}
                className="w-full h-36 object-cover rounded mb-2 cursor-pointer"
                onClick={() => setPreviewImage(img.publicUrl)}
              />
              <div className="flex-1 flex flex-col justify-between">
                <div className="flex flex-row gap-2 mt-2 justify-end">
                  <Button type="link" icon={<EditOutlined />} onClick={() => handleEdit(img)} />
                  <button
                    onClick={() => handleDelete(img)}
                    className="text-red-500 hover:text-red-700 p-2 rounded transition"
                    title="Delete"
                  >
                    <TrashIcon className="h-5 w-5" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      </Modal>
      {/* Edit Fish Image Modal */}
      <Modal
        title="Edit Fish Image"
        open={editModalVisible}
        onCancel={() => { setEditModalVisible(false); setEditingImage(null); }}
        footer={null}
        destroyOnClose
        centered
      >
        <Form form={editForm} layout="vertical" onFinish={handleEditSubmit}>
          <Form.Item
            name="common_name"
            label="Common Name"
            rules={[{ required: true, message: 'Please enter the common name' }]}
          >
            <Input placeholder="e.g. Tilapia" />
          </Form.Item>
          <Form.Item
            name="dataset"
            label="Dataset Type"
            rules={[{ required: true, message: 'Please select a dataset type' }]}
          >
            <Select placeholder="Select dataset type">
              {DATASET_TYPES.map((type) => (
                <Option key={type} value={type}>
                  {type}
                </Option>
              ))}
            </Select>
          </Form.Item>
          <Form.Item label="Current Image">
            {editingImage && (
              <img
                src={editingImage.publicUrl}
                alt={editingImage.common_name}
                className="w-full max-h-44 object-contain mb-2"
              />
            )}
          </Form.Item>
          <Form.Item
            name="file"
            label="Replace Image (optional)"
            valuePropName="fileList"
            getValueFromEvent={e => Array.isArray(e) ? e : e && e.fileList}
          >
            <Upload
              beforeUpload={() => false}
              maxCount={1}
              accept="image/*"
              listType="picture"
              customRequest={() => {}}
            >
              <Button icon={<UploadOutlined />}>Select New Image</Button>
            </Upload>
          </Form.Item>
          <Form.Item>
            <Button type="primary" htmlType="submit" loading={uploading} block>
              Update
            </Button>
          </Form.Item>
        </Form>
      </Modal>
      {/* Image Preview Modal */}
      <Modal
        open={!!previewImage}
        onCancel={() => setPreviewImage(null)}
        footer={null}
        centered
        zIndex={2000}
        width={screens.xs || screens.sm ? '95vw' : 800}
      >
        {previewImage && (
          <img
            src={previewImage}
            alt="Preview"
            className="w-full h-auto max-h-[80vh] object-contain rounded"
          />
        )}
      </Modal>
    </div>
  );
};

export default FishImages;
