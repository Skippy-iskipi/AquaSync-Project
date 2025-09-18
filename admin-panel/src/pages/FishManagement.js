import React, { useState, useEffect } from 'react';
import { 
  PlusIcon, 
  PencilIcon, 
  TrashIcon, 
  MagnifyingGlassIcon,
  EyeIcon 
} from '@heroicons/react/24/outline';
import toast from 'react-hot-toast';
import DeleteConfirmDialog from '../components/DeleteConfirmDialog';

// FishModal component definition
function FishModal({ isOpen, onClose, fish, mode, onSave }) {
  const [formData, setFormData] = useState(fish);
  const [errors, setErrors] = useState({});

  const handleChange = (e) => {
    const { name, value, type, checked } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }));
    
    // Clear error when user starts typing
    if (errors[name]) {
      setErrors(prev => ({
        ...prev,
        [name]: ''
      }));
    }
  };

  const validateForm = () => {
    const newErrors = {};
    
    // Required fields validation
    if (!formData.common_name?.trim()) {
      newErrors.common_name = 'Common name is required';
    } else if (formData.common_name.trim().length < 2) {
      newErrors.common_name = 'Common name must be at least 2 characters';
    }
    
    // Scientific name validation - now required
    if (!formData.scientific_name?.trim()) {
      newErrors.scientific_name = 'Scientific name is required';
    } else if (formData.scientific_name.trim().length < 3) {
      newErrors.scientific_name = 'Scientific name must be at least 3 characters';
    }
    
    if (!formData.water_type) {
      newErrors.water_type = 'Water type is required';
    } else if (!['Freshwater', 'Saltwater', 'Brackish'].includes(formData.water_type)) {
      newErrors.water_type = 'Water type must be Freshwater, Saltwater, or Brackish';
    }
    
    // Make temperament required
    if (!formData.temperament) {
      newErrors.temperament = 'Temperament is required';
    } else if (!['Peaceful', 'Semi-aggressive', 'Aggressive'].includes(formData.temperament)) {
      newErrors.temperament = 'Temperament must be Peaceful, Semi-aggressive, or Aggressive';
    }
    
    // Make diet required
    if (!formData.diet) {
      newErrors.diet = 'Diet is required';
    } else if (!['Omnivore', 'Herbivore', 'Carnivore'].includes(formData.diet)) {
      newErrors.diet = 'Diet must be Omnivore, Herbivore, or Carnivore';
    }
    
    // Make max size required
    if (!formData['max_size_(cm)']) {
      newErrors['max_size_(cm)'] = 'Max size is required';
    } else {
      const size = parseFloat(formData['max_size_(cm)']);
      if (isNaN(size) || size <= 0 || size > 200) {
        newErrors['max_size_(cm)'] = 'Max size must be between 0.1 and 200 cm';
      }
    }
    
    // Make minimum tank size required
    if (!formData['minimum_tank_size_(l)']) {
      newErrors['minimum_tank_size_(l)'] = 'Minimum tank size is required';
    } else {
      const tankSize = parseInt(formData['minimum_tank_size_(l)']);
      if (isNaN(tankSize) || tankSize <= 0 || tankSize > 10000) {
        newErrors['minimum_tank_size_(l)'] = 'Tank size must be between 1 and 10000 liters';
      }
    }
    
    // Make temperature range required
    if (!formData.temperature_range?.trim()) {
      newErrors.temperature_range = 'Temperature range is required';
    } else if (formData.temperature_range.trim().length < 2) {
      newErrors.temperature_range = 'Temperature range must be at least 2 characters';
    }
    
    // Make pH range required
    if (!formData.ph_range?.trim()) {
      newErrors.ph_range = 'pH range is required';
    } else if (formData.ph_range.trim().length < 2) {
      newErrors.ph_range = 'pH range must be at least 2 characters';
    }
    
    // Make lifespan required
    if (!formData.lifespan?.trim()) {
      newErrors.lifespan = 'Lifespan is required';
    } else if (formData.lifespan.trim().length < 2) {
      newErrors.lifespan = 'Lifespan must be at least 2 characters';
    }
    
    // Make social behavior required
    if (!formData.social_behavior?.trim()) {
      newErrors.social_behavior = 'Social behavior is required';
    } else if (formData.social_behavior.trim().length < 2) {
      newErrors.social_behavior = 'Social behavior must be at least 2 characters';
    }
    
    // Make preferred food required
    if (!formData.preferred_food?.trim()) {
      newErrors.preferred_food = 'Preferred food is required';
    } else if (formData.preferred_food.trim().length < 2) {
      newErrors.preferred_food = 'Preferred food must be at least 2 characters';
    }
    
    // Make feeding frequency required
    if (!formData.feeding_frequency?.trim()) {
      newErrors.feeding_frequency = 'Feeding frequency is required';
    } else if (formData.feeding_frequency.trim().length < 2) {
      newErrors.feeding_frequency = 'Feeding frequency must be at least 2 characters';
    }
    
    // Make feeding notes required
    if (!formData.feeding_notes?.trim()) {
      newErrors.feeding_notes = 'Feeding notes are required';
    } else if (formData.feeding_notes.trim().length < 5) {
      newErrors.feeding_notes = 'Feeding notes must be at least 5 characters';
    }
    
    // Make bioload required
    if (!formData.bioload) {
      newErrors.bioload = 'Bioload is required';
    } else {
      const bioload = parseFloat(formData.bioload);
      if (isNaN(bioload) || bioload < 0 || bioload > 10) {
        newErrors.bioload = 'Bioload must be between 0 and 10';
      }
    }
    
    // Make portion grams required
    if (!formData.portion_grams) {
      newErrors.portion_grams = 'Portion size is required';
    } else {
      const portion = parseFloat(formData.portion_grams);
      if (isNaN(portion) || portion <= 0 || portion > 100) {
        newErrors.portion_grams = 'Portion must be between 0.1 and 100 grams';
      }
    }
    
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (validateForm()) {
      onSave(formData);
    }
  };

  const isReadOnly = mode === 'view';

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-20 mx-auto p-5 border w-11/12 max-w-4xl shadow-lg rounded-md bg-white">
        <div className="mt-3">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              {mode === 'add' ? 'Add New Fish Species' : 
               mode === 'edit' ? 'Edit Fish Species' : 'Fish Species Details'}
            </h3>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600"
            >
              <span className="sr-only">Close</span>
              ×
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {/* Basic Information */}
              <div>
                <label className="block text-sm font-medium text-gray-700">Common Name *</label>
                <input
                  type="text"
                  name="common_name"
                  value={formData.common_name || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.common_name ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  required
                />
                {errors.common_name && (
                  <p className="mt-1 text-sm text-red-600">{errors.common_name}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Scientific Name *</label>
                <input
                  type="text"
                  name="scientific_name"
                  value={formData.scientific_name || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.scientific_name ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., Betta splendens"
                  required
                />
                {errors.scientific_name && (
                  <p className="mt-1 text-sm text-red-600">{errors.scientific_name}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Max Size (cm) *</label>
                <input
                  type="number"
                  name="max_size_(cm)"
                  value={formData['max_size_(cm)'] || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors['max_size_(cm)'] ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  min="0"
                  step="0.1"
                  required
                />
                {errors['max_size_(cm)'] && (
                  <p className="mt-1 text-sm text-red-600">{errors['max_size_(cm)']}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Temperament *</label>
                <select
                  name="temperament"
                  value={formData.temperament || ''}
                  onChange={handleChange}
                  disabled={isReadOnly}
                  className={`input-field ${errors.temperament ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  required
                >
                  <option value="">Select temperament *</option>
                  <option value="Peaceful">Peaceful</option>
                  <option value="Semi-aggressive">Semi-aggressive</option>
                  <option value="Aggressive">Aggressive</option>
                </select>
                {errors.temperament && (
                  <p className="mt-1 text-sm text-red-600">{errors.temperament}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Water Type *</label>
                <select
                  name="water_type"
                  value={formData.water_type || ''}
                  onChange={handleChange}
                  disabled={isReadOnly}
                  className={`input-field ${errors.water_type ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  required
                >
                  <option value="">Select water type *</option>
                  <option value="Freshwater">Freshwater</option>
                  <option value="Saltwater">Saltwater</option>
                  <option value="Brackish">Brackish</option>
                </select>
                {errors.water_type && (
                  <p className="mt-1 text-sm text-red-600">{errors.water_type}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">pH Range *</label>
                <input
                  type="text"
                  name="ph_range"
                  value={formData.ph_range || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.ph_range ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., 6.0-7.5 or 6-8"
                  required
                />
                {errors.ph_range && (
                  <p className="mt-1 text-sm text-red-600">{errors.ph_range}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Social Behavior *</label>
                <input
                  type="text"
                  name="social_behavior"
                  value={formData.social_behavior || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.social_behavior ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., Community, Schooling, Solitary"
                  required
                />
                {errors.social_behavior && (
                  <p className="mt-1 text-sm text-red-600">{errors.social_behavior}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Minimum Tank Size (L) *</label>
                <input
                  type="number"
                  name="minimum_tank_size_(l)"
                  value={formData['minimum_tank_size_(l)'] || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors['minimum_tank_size_(l)'] ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  min="0"
                  step="1"
                  required
                />
                {errors['minimum_tank_size_(l)'] && (
                  <p className="mt-1 text-sm text-red-600">{errors['minimum_tank_size_(l)']}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Temperature Range *</label>
                <input
                  type="text"
                  name="temperature_range"
                  value={formData.temperature_range || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.temperature_range ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., 22-26°C or 72-79°F or 22-26"
                  required
                />
                {errors.temperature_range && (
                  <p className="mt-1 text-sm text-red-600">{errors.temperature_range}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Diet *</label>
                <select
                  name="diet"
                  value={formData.diet || ''}
                  onChange={handleChange}
                  disabled={isReadOnly}
                  className={`input-field ${errors.diet ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  required
                >
                  <option value="">Select diet *</option>
                  <option value="Omnivore">Omnivore</option>
                  <option value="Herbivore">Herbivore</option>
                  <option value="Carnivore">Carnivore</option>
                </select>
                {errors.diet && (
                  <p className="mt-1 text-sm text-red-600">{errors.diet}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Lifespan *</label>
                <input
                  type="text"
                  name="lifespan"
                  value={formData.lifespan || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.lifespan ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., 5-7 years or 10 years or 5-10"
                  required
                />
                {errors.lifespan && (
                  <p className="mt-1 text-sm text-red-600">{errors.lifespan}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Preferred Food *</label>
                <input
                  type="text"
                  name="preferred_food"
                  value={formData.preferred_food || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.preferred_food ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., Flakes, Pellets, Live food"
                  required
                />
                {errors.preferred_food && (
                  <p className="mt-1 text-sm text-red-600">{errors.preferred_food}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Feeding Frequency *</label>
                <input
                  type="text"
                  name="feeding_frequency"
                  value={formData.feeding_frequency || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.feeding_frequency ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="e.g., daily, twice daily, weekly, 2 times per day"
                  required
                />
                {errors.feeding_frequency && (
                  <p className="mt-1 text-sm text-red-600">{errors.feeding_frequency}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Bioload *</label>
                <input
                  type="number"
                  name="bioload"
                  value={formData.bioload || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.bioload ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  placeholder="0-10 scale"
                  min="0"
                  max="10"
                  step="0.1"
                  required
                />
                {errors.bioload && (
                  <p className="mt-1 text-sm text-red-600">{errors.bioload}</p>
                )}
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700">Portion (grams) *</label>
                <input
                  type="number"
                  name="portion_grams"
                  value={formData.portion_grams || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.portion_grams ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  min="0"
                  step="0.1"
                  required
                />
                {errors.portion_grams && (
                  <p className="mt-1 text-sm text-red-600">{errors.portion_grams}</p>
                )}
              </div>

              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700">Feeding Notes *</label>
                <textarea
                  name="feeding_notes"
                  value={formData.feeding_notes || ''}
                  onChange={handleChange}
                  readOnly={isReadOnly}
                  className={`input-field ${errors.feeding_notes ? 'border-red-500 focus:border-red-500 focus:ring-red-500' : ''}`}
                  rows="3"
                  placeholder="Additional feeding instructions or notes..."
                  required
                />
                {errors.feeding_notes && (
                  <p className="mt-1 text-sm text-red-600">{errors.feeding_notes}</p>
                )}
              </div>
            </div>

            {!isReadOnly && (
              <div className="flex justify-end space-x-3 pt-6 border-t">
                <button
                  type="button"
                  onClick={onClose}
                  className="btn-secondary"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn-primary"
                >
                  {mode === 'add' ? 'Add Fish' : 'Update Fish'}
                </button>
              </div>
            )}
          </form>
        </div>
      </div>
    </div>
  );
}

function FishManagement() {
  const [fish, setFish] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedFish, setSelectedFish] = useState(null);
  const [showModal, setShowModal] = useState(false);
  const [modalMode, setModalMode] = useState('view'); // 'view', 'edit', 'add'
  const [currentPage, setCurrentPage] = useState(1);
  const [itemsPerPage] = useState(10);
  const [showDeleteDialog, setShowDeleteDialog] = useState(false);
  const [fishToDelete, setFishToDelete] = useState(null);

  useEffect(() => {
    fetchFish();
  }, []);

  const fetchFish = async () => {
    try {
      const token = localStorage.getItem('adminToken');
      const response = await fetch('/api/fish', {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });
      const data = await response.json();
      setFish(Array.isArray(data) ? data : []);
    } catch (error) {
      toast.error('Failed to fetch fish data');
      console.error('Error fetching fish:', error);
      setFish([]); // Ensure fish is always an array
    } finally {
      setLoading(false);
    }
  };

  const handleAddFish = () => {
    setSelectedFish({
      common_name: '',
      scientific_name: '',
      'max_size_(cm)': '',
      temperament: 'Peaceful',
      water_type: 'Freshwater',
      ph_range: '',
      social_behavior: 'Community',
      'minimum_tank_size_(l)': '',
      temperature_range: '',
      diet: 'Omnivore',
      lifespan: '',
      preferred_food: '',
      feeding_frequency: '',
      bioload: '',
      portion_grams: '',
      feeding_notes: ''
    });
    setModalMode('add');
    setShowModal(true);
  };

  const handleEditFish = (fishData) => {
    setSelectedFish(fishData);
    setModalMode('edit');
    setShowModal(true);
  };

  const handleViewFish = (fishData) => {
    setSelectedFish(fishData);
    setModalMode('view');
    setShowModal(true);
  };

  const handleDeleteFish = (fishId) => {
    setFishToDelete(fishId);
    setShowDeleteDialog(true);
  };

  const confirmDeleteFish = async () => {
    if (!fishToDelete) return;
    
    try {
      const response = await fetch(`/api/fish/${fishToDelete}`, {
        method: 'DELETE',
      });
      
      if (response.ok) {
        toast.success('Fish species deleted successfully');
        fetchFish();
      } else {
        toast.error('Failed to delete fish species');
      }
    } catch (error) {
      toast.error('Error deleting fish species');
      console.error('Error:', error);
    } finally {
      setShowDeleteDialog(false);
      setFishToDelete(null);
    }
  };

  const handleSaveFish = async (fishData) => {
    try {
      const url = modalMode === 'add' ? '/api/fish' : `/api/fish/${fishData.id}`;
      const method = modalMode === 'add' ? 'POST' : 'PUT';
      
      const response = await fetch(url, {
        method,
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(fishData),
      });

      if (response.ok) {
        toast.success(`Fish species ${modalMode === 'add' ? 'added' : 'updated'} successfully`);
        setShowModal(false);
        fetchFish();
      } else {
        const errorData = await response.json();
        console.error('API Error:', errorData);
        if (errorData.errors && errorData.errors.length > 0) {
          console.error('Validation errors:', errorData.errors);
          const errorMessages = errorData.errors.map(err => `${err.path}: ${err.msg}`).join(', ');
          toast.error(`Validation failed: ${errorMessages}`);
        } else {
          toast.error(`Failed to ${modalMode === 'add' ? 'add' : 'update'} fish species: ${errorData.message || 'Unknown error'}`);
        }
      }
    } catch (error) {
      toast.error('Error saving fish species');
      console.error('Error:', error);
    }
  };

  const filteredFish = fish.filter(f => {
    if (!searchTerm) return true;
    
    const searchLower = searchTerm.toLowerCase();
    
    // Search across multiple characteristics
    return (
      f.common_name?.toLowerCase().includes(searchLower) ||
      f.scientific_name?.toLowerCase().includes(searchLower) ||
      f.temperament?.toLowerCase().includes(searchLower) ||
      f.water_type?.toLowerCase().includes(searchLower) ||
      f.diet?.toLowerCase().includes(searchLower) ||
      f.social_behavior?.toLowerCase().includes(searchLower) ||
      f.preferred_food?.toLowerCase().includes(searchLower) ||
      f.feeding_frequency?.toLowerCase().includes(searchLower) ||
      f.ph_range?.toLowerCase().includes(searchLower) ||
      f.temperature_range?.toLowerCase().includes(searchLower) ||
      f.lifespan?.toLowerCase().includes(searchLower) ||
      (f.bioload && f.bioload.toString().toLowerCase().includes(searchLower)) ||
      f.feeding_notes?.toLowerCase().includes(searchLower) ||
      // Search by size ranges
      (f['max_size_(cm)'] && f['max_size_(cm)'].toString().includes(searchTerm)) ||
      (f['minimum_tank_size_(l)'] && f['minimum_tank_size_(l)'].toString().includes(searchTerm)) ||
      (f.portion_grams && f.portion_grams.toString().includes(searchTerm))
    );
  });

  const indexOfLastItem = currentPage * itemsPerPage;
  const indexOfFirstItem = indexOfLastItem - itemsPerPage;
  const currentItems = filteredFish.slice(indexOfFirstItem, indexOfLastItem);
  const totalPages = Math.ceil(filteredFish.length / itemsPerPage);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-aqua-500"></div>
      </div>
    );
  }

  return (
    <div>
      <div className="sm:flex sm:items-center mb-6">
        <div className="sm:flex-auto">
          <h1 className="text-2xl font-semibold text-gray-900">Fish Management</h1>
          <p className="mt-2 text-sm text-gray-700">
            Manage fish species in the database with CRUD operations
          </p>
        </div>
        <div className="mt-4 sm:mt-0 sm:ml-16 sm:flex-none">
          <button
            onClick={handleAddFish}
            className="inline-flex items-center justify-center rounded-md border border-transparent bg-aqua-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-aqua-700 focus:outline-none focus:ring-2 focus:ring-aqua-500 focus:ring-offset-2 sm:w-auto"
          >
            <PlusIcon className="h-4 w-4 mr-2" />
            Add Fish Species
          </button>
        </div>
      </div>

      {/* Search */}
      <div className="mb-6">
        <div className="relative">
          <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
            <MagnifyingGlassIcon className="h-5 w-5 text-gray-400" />
          </div>
          <input
            type="text"
            placeholder="Search by name, temperament, water type, diet, size, or any characteristic..."
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            className="block w-full pl-10 pr-3 py-2 border border-gray-300 rounded-md leading-5 bg-white placeholder-gray-500 focus:outline-none focus:placeholder-gray-400 focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500 sm:text-sm"
          />
        </div>
      </div>

      {/* Fish Table */}
      <div className="bg-white shadow overflow-hidden sm:rounded-md">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="table-header">Common Name</th>
              <th className="table-header">Scientific Name</th>
              <th className="table-header">Temperament</th>
              <th className="table-header">Water Type</th>
              <th className="table-header">Diet</th>
              <th className="table-header">Lifespan</th>
              <th className="table-header">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {currentItems.map((fishItem, index) => (
              <tr key={fishItem.id || `fish-${index}`} className="hover:bg-gray-50">
                <td className="table-cell font-medium">{fishItem.common_name}</td>
                <td className="table-cell italic">{fishItem.scientific_name}</td>
                <td className="table-cell">
                  <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                    fishItem.temperament === 'Peaceful' 
                      ? 'bg-green-100 text-green-800'
                      : fishItem.temperament === 'Semi-aggressive'
                      ? 'bg-yellow-100 text-yellow-800'
                      : 'bg-red-100 text-red-800'
                  }`}>
                    {fishItem.temperament}
                  </span>
                </td>
                <td className="table-cell">
                  <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                    fishItem.water_type === 'Freshwater' 
                      ? 'bg-blue-100 text-blue-800'
                      : 'bg-teal-100 text-teal-800'
                  }`}>
                    {fishItem.water_type}
                  </span>
                </td>
                <td className="table-cell">{fishItem.diet || 'N/A'}</td>
                <td className="table-cell">{fishItem.lifespan || 'N/A'}</td>
                <td className="table-cell">
                  <div className="flex space-x-2">
                    <button
                      onClick={() => handleViewFish(fishItem)}
                      className="text-aqua-600 hover:text-aqua-900"
                    >
                      <EyeIcon className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleEditFish(fishItem)}
                      className="text-indigo-600 hover:text-indigo-900"
                    >
                      <PencilIcon className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleDeleteFish(fishItem.id)}
                      className="text-red-600 hover:text-red-900"
                    >
                      <TrashIcon className="h-4 w-4" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="mt-6 flex items-center justify-between">
          <div className="text-sm text-gray-700">
            Showing {indexOfFirstItem + 1} to {Math.min(indexOfLastItem, filteredFish.length)} of {filteredFish.length} results
          </div>
          <div className="flex space-x-2">
            <button
              onClick={() => setCurrentPage(prev => Math.max(prev - 1, 1))}
              disabled={currentPage === 1}
              className="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
            >
              Previous
            </button>
            <button
              onClick={() => setCurrentPage(prev => Math.min(prev + 1, totalPages))}
              disabled={currentPage === totalPages}
              className="px-3 py-2 text-sm font-medium text-gray-500 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {/* Fish Modal */}
      {showModal && (
        <FishModal
          isOpen={showModal}
          fish={selectedFish}
          mode={modalMode}
          onSave={handleSaveFish}
          onClose={() => setShowModal(false)}
        />
      )}

      {/* Delete Confirmation Dialog */}
      <DeleteConfirmDialog
        isOpen={showDeleteDialog}
        onClose={() => setShowDeleteDialog(false)}
        onConfirm={confirmDeleteFish}
        title="Delete Fish Species"
        message="Are you sure you want to delete this fish species? This action cannot be undone."
        confirmText="Delete Fish"
        cancelText="Cancel"
      />
    </div>
  );
}

export default FishManagement;
