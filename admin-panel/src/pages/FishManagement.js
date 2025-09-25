import React, { useState, useEffect } from 'react';
import { 
  PlusIcon, 
  PencilIcon, 
  MagnifyingGlassIcon,
  EyeIcon,
  CheckCircleIcon,
  XCircleIcon,
  FunnelIcon,
  XMarkIcon,
  DocumentArrowUpIcon,
  DocumentArrowDownIcon
} from '@heroicons/react/24/outline';
import toast from 'react-hot-toast';
import * as XLSX from 'xlsx';

// BulkUploadModal component definition
function BulkUploadModal({ isOpen, onClose, onUpload }) {
  const [file, setFile] = useState(null);
  const [uploading, setUploading] = useState(false);
  const [previewData, setPreviewData] = useState([]);
  const [showPreview, setShowPreview] = useState(false);
  const [errors, setErrors] = useState([]);

  const handleFileChange = (e) => {
    const selectedFile = e.target.files[0];
    if (selectedFile) {
      setFile(selectedFile);
      setErrors([]);
      setPreviewData([]);
      setShowPreview(false);
      
      // Validate file type
      const validTypes = [
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-excel',
        'text/csv'
      ];
      
      if (!validTypes.includes(selectedFile.type)) {
        setErrors(['Please select a valid Excel file (.xlsx, .xls) or CSV file']);
        return;
      }
      
      // Parse and preview the file
      parseFile(selectedFile);
    }
  };

  const parseFile = (file) => {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        const jsonData = XLSX.utils.sheet_to_json(worksheet);
        
        // Validate and clean the data
        const validatedData = validateBulkData(jsonData);
        setPreviewData(validatedData.valid);
        setErrors(validatedData.errors);
        setShowPreview(true);
      } catch (error) {
        setErrors(['Error parsing file. Please check the file format.']);
      }
    };
    reader.readAsArrayBuffer(file);
  };

  const validateBulkData = (data) => {
    const valid = [];
    const errors = [];
    const requiredFields = [
      'common_name', 'scientific_name', 'water_type', 'temperament', 
      'diet', 'max_size_(cm)', 'minimum_tank_size_(l)', 'ph_range',
      'temperature_range', 'social_behavior', 'lifespan', 'preferred_food',
      'feeding_frequency', 'bioload', 'portion_grams', 'feeding_notes'
    ];

    data.forEach((row, index) => {
      const rowErrors = [];
      
      // Check required fields
      requiredFields.forEach(field => {
        if (!row[field] || row[field].toString().trim() === '') {
          rowErrors.push(`Row ${index + 2}: ${field} is required`);
        }
      });

      // Validate specific fields
      if (row['max_size_(cm)'] && (isNaN(row['max_size_(cm)']) || row['max_size_(cm)'] <= 0)) {
        rowErrors.push(`Row ${index + 2}: max_size_(cm) must be a positive number`);
      }
      
      if (row['minimum_tank_size_(l)'] && (isNaN(row['minimum_tank_size_(l)']) || row['minimum_tank_size_(l)'] <= 0)) {
        rowErrors.push(`Row ${index + 2}: minimum_tank_size_(l) must be a positive number`);
      }
      
      if (row['bioload'] && (isNaN(row['bioload']) || row['bioload'] < 0 || row['bioload'] > 10)) {
        rowErrors.push(`Row ${index + 2}: bioload must be between 0 and 10`);
      }
      
      if (row['portion_grams'] && (isNaN(row['portion_grams']) || row['portion_grams'] <= 0)) {
        rowErrors.push(`Row ${index + 2}: portion_grams must be a positive number`);
      }

      if (row['water_type'] && !['Freshwater', 'Saltwater'].includes(row['water_type'])) {
        rowErrors.push(`Row ${index + 2}: water_type must be 'Freshwater' or 'Saltwater'`);
      }

      if (row['temperament'] && !['Peaceful', 'Semi-aggressive', 'Aggressive'].includes(row['temperament'])) {
        rowErrors.push(`Row ${index + 2}: temperament must be 'Peaceful', 'Semi-aggressive', or 'Aggressive'`);
      }

      if (row['diet'] && !['Omnivore', 'Herbivore', 'Carnivore'].includes(row['diet'])) {
        rowErrors.push(`Row ${index + 2}: diet must be 'Omnivore', 'Herbivore', or 'Carnivore'`);
      }

      if (rowErrors.length === 0) {
        valid.push(row);
      } else {
        errors.push(...rowErrors);
      }
    });

    return { valid, errors };
  };

  const handleUpload = async () => {
    if (previewData.length === 0) {
      toast.error('No valid data to upload');
      return;
    }

    setUploading(true);
    try {
      await onUpload(previewData);
      setFile(null);
      setPreviewData([]);
      setShowPreview(false);
      setErrors([]);
      onClose();
    } catch (error) {
      toast.error('Upload failed. Please try again.');
    } finally {
      setUploading(false);
    }
  };

  const downloadTemplate = () => {
    const templateData = [{
      'common_name': 'Goldfish',
      'scientific_name': 'Carassius auratus',
      'water_type': 'Freshwater',
      'temperament': 'Peaceful',
      'diet': 'Omnivore',
      'max_size_(cm)': 30,
      'minimum_tank_size_(l)': 75,
      'ph_range': '6.0-8.0',
      'temperature_range': '18-22°C',
      'social_behavior': 'Community',
      'lifespan': '10-15 years',
      'preferred_food': 'Pellets, Flakes',
      'feeding_frequency': '2 times daily',
      'bioload': 3,
      'portion_grams': 5,
      'feeding_notes': 'Feed small amounts twice daily'
    }];

    const ws = XLSX.utils.json_to_sheet(templateData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Fish Species');
    XLSX.writeFile(wb, 'fish_species_template.xlsx');
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-20 mx-auto p-5 border w-11/12 max-w-4xl shadow-lg rounded-md bg-white">
        <div className="mt-3">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">
              Bulk Upload Fish Species
            </h3>
            <button
              onClick={onClose}
              className="text-gray-400 hover:text-gray-600"
            >
              <span className="sr-only">Close</span>
              ×
            </button>
          </div>

          <div className="space-y-6">
            {/* Template Download */}
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-sm font-medium text-blue-900">Download Template</h4>
                  <p className="text-sm text-blue-700">Download the Excel template to see the required format</p>
                </div>
                <button
                  onClick={downloadTemplate}
                  className="inline-flex items-center px-3 py-2 border border-blue-300 text-sm font-medium rounded-md text-blue-700 bg-white hover:bg-blue-50"
                >
                  <DocumentArrowDownIcon className="h-4 w-4 mr-2" />
                  Download Template
                </button>
              </div>
            </div>

            {/* File Upload */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Select Excel File
              </label>
              <input
                type="file"
                accept=".xlsx,.xls,.csv"
                onChange={handleFileChange}
                className="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-aqua-50 file:text-aqua-700 hover:file:bg-aqua-100"
              />
              <p className="mt-1 text-xs text-gray-500">
                Supported formats: .xlsx, .xls, .csv
              </p>
            </div>

            {/* Errors */}
            {errors.length > 0 && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                <h4 className="text-sm font-medium text-red-900 mb-2">Validation Errors</h4>
                <ul className="text-sm text-red-700 space-y-1 max-h-32 overflow-y-auto">
                  {errors.map((error, index) => (
                    <li key={index}>• {error}</li>
                  ))}
                </ul>
              </div>
            )}

            {/* Preview */}
            {showPreview && previewData.length > 0 && (
              <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                <h4 className="text-sm font-medium text-green-900 mb-2">
                  Preview ({previewData.length} valid records)
                </h4>
                <div className="overflow-x-auto max-h-64">
                  <table className="min-w-full text-xs">
                    <thead className="bg-green-100">
                      <tr>
                        <th className="px-2 py-1 text-left">Common Name</th>
                        <th className="px-2 py-1 text-left">Scientific Name</th>
                        <th className="px-2 py-1 text-left">Water Type</th>
                        <th className="px-2 py-1 text-left">Temperament</th>
                      </tr>
                    </thead>
                    <tbody className="bg-white divide-y divide-green-200">
                      {previewData.slice(0, 10).map((row, index) => (
                        <tr key={index}>
                          <td className="px-2 py-1">{row.common_name}</td>
                          <td className="px-2 py-1 italic">{row.scientific_name}</td>
                          <td className="px-2 py-1">{row.water_type}</td>
                          <td className="px-2 py-1">{row.temperament}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                  {previewData.length > 10 && (
                    <p className="text-xs text-green-600 mt-2">
                      ... and {previewData.length - 10} more records
                    </p>
                  )}
                </div>
              </div>
            )}

            {/* Actions */}
            <div className="flex justify-end space-x-3 pt-6 border-t">
              <button
                type="button"
                onClick={onClose}
                className="btn-secondary"
                disabled={uploading}
              >
                Cancel
              </button>
              <button
                onClick={handleUpload}
                disabled={!file || previewData.length === 0 || uploading}
                className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {uploading ? 'Uploading...' : `Upload ${previewData.length} Fish Species`}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

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
    } else if (!['Freshwater', 'Saltwater'].includes(formData.water_type)) {
      newErrors.water_type = 'Water type must be Freshwater or Saltwater';
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
  const [showStatusDialog, setShowStatusDialog] = useState(false);
  const [fishToToggle, setFishToToggle] = useState(null);
  const [newStatus, setNewStatus] = useState(null);
  const [showBulkUpload, setShowBulkUpload] = useState(false);
  
  // Filter states
  const [showFilters, setShowFilters] = useState(false);
  const [filters, setFilters] = useState({
    temperament: '',
    water_type: '',
    diet: '',
    status: '',
    size_range: '',
    tank_size_range: ''
  });

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
      // Error fetching fish data
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

  const handleToggleStatus = (fishItem) => {
    setFishToToggle(fishItem);
    setNewStatus(!fishItem.active);
    setShowStatusDialog(true);
  };

  const confirmToggleStatus = async () => {
    if (!fishToToggle) return;
    
    try {
      const token = localStorage.getItem('adminToken');
      const response = await fetch(`/api/fish/${fishToToggle.id}/status`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ active: newStatus })
      });
      
      if (response.ok) {
        toast.success(`Fish species ${newStatus ? 'activated' : 'deactivated'} successfully`);
        fetchFish();
      } else {
        toast.error(`Failed to ${newStatus ? 'activate' : 'deactivate'} fish species`);
      }
    } catch (error) {
      toast.error(`Error ${newStatus ? 'activating' : 'deactivating'} fish species`);
      // Error occurred during operation
    } finally {
      setShowStatusDialog(false);
      setFishToToggle(null);
      setNewStatus(null);
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
        // API Error occurred
        if (errorData.errors && errorData.errors.length > 0) {
          // Validation errors occurred
          const errorMessages = errorData.errors.map(err => `${err.path}: ${err.msg}`).join(', ');
          toast.error(`Validation failed: ${errorMessages}`);
        } else {
          toast.error(`Failed to ${modalMode === 'add' ? 'add' : 'update'} fish species: ${errorData.message || 'Unknown error'}`);
        }
      }
    } catch (error) {
      toast.error('Error saving fish species');
      // Error occurred during operation
    }
  };

  const handleBulkUpload = async (fishDataArray) => {
    try {
      const token = localStorage.getItem('adminToken');
      const response = await fetch('/api/fish/bulk', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ fish: fishDataArray }),
      });

      if (response.ok) {
        const result = await response.json();
        toast.success(`Successfully uploaded ${result.successCount} fish species. ${result.errorCount > 0 ? `${result.errorCount} failed.` : ''}`);
        fetchFish();
      } else {
        const errorData = await response.json();
        toast.error(`Bulk upload failed: ${errorData.message || 'Unknown error'}`);
      }
    } catch (error) {
      toast.error('Error during bulk upload');
      // Error occurred during operation
    }
  };

  // Filter functions
  const handleFilterChange = (filterType, value) => {
    setFilters(prev => ({
      ...prev,
      [filterType]: value
    }));
  };

  const clearFilters = () => {
    setFilters({
      temperament: '',
      water_type: '',
      diet: '',
      status: '',
      size_range: '',
      tank_size_range: ''
    });
  };

  const getActiveFiltersCount = () => {
    return Object.values(filters).filter(value => value !== '').length;
  };

  const filteredFish = fish.filter(f => {
    // Text search
    if (searchTerm) {
      const searchLower = searchTerm.toLowerCase();
      const matchesSearch = (
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
      (f['max_size_(cm)'] && f['max_size_(cm)'].toString().includes(searchTerm)) ||
      (f['minimum_tank_size_(l)'] && f['minimum_tank_size_(l)'].toString().includes(searchTerm)) ||
      (f.portion_grams && f.portion_grams.toString().includes(searchTerm))
    );
      if (!matchesSearch) return false;
    }

    // Filter by temperament
    if (filters.temperament && f.temperament !== filters.temperament) return false;

    // Filter by water type
    if (filters.water_type && f.water_type !== filters.water_type) return false;

    // Filter by diet
    if (filters.diet && f.diet !== filters.diet) return false;

    // Filter by status
    if (filters.status) {
      const isActive = f.active === true || f.active === 'true';
      if (filters.status === 'active' && !isActive) return false;
      if (filters.status === 'inactive' && isActive) return false;
    }

    // Filter by size range
    if (filters.size_range) {
      const size = parseFloat(f['max_size_(cm)']);
      if (!isNaN(size)) {
        switch (filters.size_range) {
          case 'small':
            if (size > 10) return false;
            break;
          case 'medium':
            if (size <= 10 || size > 30) return false;
            break;
          case 'large':
            if (size <= 30) return false;
            break;
          default:
            break;
        }
      }
    }

    // Filter by tank size range
    if (filters.tank_size_range) {
      const tankSize = parseInt(f['minimum_tank_size_(l)']);
      if (!isNaN(tankSize)) {
        switch (filters.tank_size_range) {
          case 'small':
            if (tankSize > 50) return false;
            break;
          case 'medium':
            if (tankSize <= 50 || tankSize > 200) return false;
            break;
          case 'large':
            if (tankSize <= 200) return false;
            break;
          default:
            break;
        }
      }
    }

    return true;
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
        <div className="mt-4 sm:mt-0 sm:ml-16 sm:flex-none space-x-3">
          <button
            onClick={() => setShowBulkUpload(true)}
            className="inline-flex items-center justify-center rounded-md border border-aqua-300 bg-white px-4 py-2 text-sm font-medium text-aqua-700 shadow-sm hover:bg-aqua-50 focus:outline-none focus:ring-2 focus:ring-aqua-500 focus:ring-offset-2 sm:w-auto"
          >
            <DocumentArrowUpIcon className="h-4 w-4 mr-2" />
            Bulk Upload
          </button>
          <button
            onClick={handleAddFish}
            className="inline-flex items-center justify-center rounded-md border border-transparent bg-aqua-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-aqua-700 focus:outline-none focus:ring-2 focus:ring-aqua-500 focus:ring-offset-2 sm:w-auto"
          >
            <PlusIcon className="h-4 w-4 mr-2" />
            Add Fish Species
          </button>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="mb-6 space-y-4">
        {/* Search Bar */}
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

        {/* Filter Controls */}
        <div className="flex flex-wrap items-center gap-3">
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`inline-flex items-center px-4 py-2 text-sm font-medium rounded-md border transition-colors ${
              showFilters || getActiveFiltersCount() > 0
                ? 'bg-aqua-50 border-aqua-300 text-aqua-700'
                : 'bg-white border-gray-300 text-gray-700 hover:bg-gray-50'
            }`}
          >
            <FunnelIcon className="h-4 w-4 mr-2" />
            Filters
            {getActiveFiltersCount() > 0 && (
              <span className="ml-2 inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-aqua-100 text-aqua-800">
                {getActiveFiltersCount()}
              </span>
            )}
          </button>

          {getActiveFiltersCount() > 0 && (
            <button
              onClick={clearFilters}
              className="inline-flex items-center px-3 py-2 text-sm font-medium text-gray-500 hover:text-gray-700"
            >
              <XMarkIcon className="h-4 w-4 mr-1" />
              Clear All
            </button>
          )}

          <div className="text-sm text-gray-500">
            {filteredFish.length} of {fish.length} fish
        </div>
      </div>

        {/* Filter Panel */}
        {showFilters && (
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {/* Temperament Filter */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Temperament</label>
                <select
                  value={filters.temperament}
                  onChange={(e) => handleFilterChange('temperament', e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500"
                >
                  <option value="">All Temperaments</option>
                  <option value="Peaceful">Peaceful</option>
                  <option value="Semi-aggressive">Semi-aggressive</option>
                  <option value="Aggressive">Aggressive</option>
                </select>
              </div>

              {/* Water Type Filter */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Water Type</label>
                <select
                  value={filters.water_type}
                  onChange={(e) => handleFilterChange('water_type', e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500"
                >
                  <option value="">All Water Types</option>
                  <option value="Freshwater">Freshwater</option>
                  <option value="Saltwater">Saltwater</option>
                </select>
              </div>

              {/* Diet Filter */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Diet</label>
                <select
                  value={filters.diet}
                  onChange={(e) => handleFilterChange('diet', e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500"
                >
                  <option value="">All Diets</option>
                  <option value="Omnivore">Omnivore</option>
                  <option value="Herbivore">Herbivore</option>
                  <option value="Carnivore">Carnivore</option>
                </select>
              </div>

              {/* Status Filter */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Status</label>
                <select
                  value={filters.status}
                  onChange={(e) => handleFilterChange('status', e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500"
                >
                  <option value="">All Status</option>
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </div>

              {/* Size Range Filter */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Fish Size</label>
                <select
                  value={filters.size_range}
                  onChange={(e) => handleFilterChange('size_range', e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500"
                >
                  <option value="">All Sizes</option>
                  <option value="small">Small (≤10cm)</option>
                  <option value="medium">Medium (10-30cm)</option>
                  <option value="large">Large (&gt;30cm)</option>
                </select>
              </div>

              {/* Tank Size Range Filter */}
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">Tank Size</label>
                <select
                  value={filters.tank_size_range}
                  onChange={(e) => handleFilterChange('tank_size_range', e.target.value)}
                  className="w-full px-3 py-2 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-1 focus:ring-aqua-500 focus:border-aqua-500"
                >
                  <option value="">All Tank Sizes</option>
                  <option value="small">Small (≤50L)</option>
                  <option value="medium">Medium (50-200L)</option>
                  <option value="large">Large (&gt;200L)</option>
                </select>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Fish Table - Desktop View */}
      <div className="hidden md:block bg-white shadow overflow-hidden sm:rounded-md">
        <div className="table-container">
          <table className="table-mobile">
          <thead className="bg-gray-50">
            <tr>
                <th className="table-mobile-header">Common Name</th>
                <th className="table-mobile-header">Scientific Name</th>
                <th className="table-mobile-header">Temperament</th>
                <th className="table-mobile-header">Water Type</th>
                <th className="table-mobile-header">Status</th>
                <th className="table-mobile-header">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {currentItems.map((fishItem, index) => (
              <tr key={fishItem.id || `fish-${index}`} className="hover:bg-gray-50">
                  <td className="table-mobile-cell font-medium">{fishItem.common_name}</td>
                  <td className="table-mobile-cell italic">{fishItem.scientific_name}</td>
                  <td className="table-mobile-cell">
                    <span className={`status-badge ${
                    fishItem.temperament === 'Peaceful' 
                        ? 'status-badge-green'
                      : fishItem.temperament === 'Semi-aggressive'
                        ? 'status-badge-yellow'
                        : 'status-badge-red'
                  }`}>
                    {fishItem.temperament}
                  </span>
                </td>
                  <td className="table-mobile-cell">
                    <span className={`status-badge ${
                    fishItem.water_type === 'Freshwater' 
                        ? 'status-badge-blue'
                        : 'status-badge-teal'
                  }`}>
                    {fishItem.water_type}
                  </span>
                </td>
                  <td className="table-mobile-cell">
                    <span className={`status-badge ${
                    fishItem.active 
                        ? 'status-badge-green'
                        : 'status-badge-red'
                  }`}>
                    {fishItem.active ? 'Active' : 'Inactive'}
                  </span>
                </td>
                  <td className="table-mobile-cell">
                  <div className="flex space-x-2">
                    <button
                      onClick={() => handleViewFish(fishItem)}
                      className="text-aqua-600 hover:text-aqua-900"
                      title="View Details"
                    >
                      <EyeIcon className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleEditFish(fishItem)}
                      className="text-indigo-600 hover:text-indigo-900"
                      title="Edit Fish"
                    >
                      <PencilIcon className="h-4 w-4" />
                    </button>
                    <button
                      onClick={() => handleToggleStatus(fishItem)}
                      className={`${fishItem.active ? 'text-red-600 hover:text-red-900' : 'text-green-600 hover:text-green-900'}`}
                      title={fishItem.active ? 'Deactivate Fish' : 'Activate Fish'}
                    >
                      {fishItem.active ? (
                        <XCircleIcon className="h-4 w-4" />
                      ) : (
                        <CheckCircleIcon className="h-4 w-4" />
                      )}
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        </div>
      </div>

      {/* Fish Cards - Mobile View */}
      <div className="md:hidden space-y-4">
        {currentItems.map((fishItem, index) => (
          <div key={fishItem.id || `fish-${index}`} className="mobile-card">
            <div className="mobile-card-header">
              <div>
                <h3 className="mobile-card-title">{fishItem.common_name}</h3>
                <p className="mobile-card-subtitle italic">{fishItem.scientific_name}</p>
              </div>
              <span className={`status-badge ${
                fishItem.active 
                  ? 'status-badge-green'
                  : 'status-badge-red'
              }`}>
                {fishItem.active ? 'Active' : 'Inactive'}
              </span>
            </div>
            
            <div className="mobile-card-content">
              <div className="mobile-card-row">
                <span className="mobile-card-label">Temperament</span>
                <span className={`mobile-card-value status-badge ${
                  fishItem.temperament === 'Peaceful' 
                    ? 'status-badge-green'
                    : fishItem.temperament === 'Semi-aggressive'
                    ? 'status-badge-yellow'
                    : 'status-badge-red'
                }`}>
                  {fishItem.temperament}
                </span>
              </div>
              
              <div className="mobile-card-row">
                <span className="mobile-card-label">Water Type</span>
                <span className={`mobile-card-value status-badge ${
                  fishItem.water_type === 'Freshwater' 
                    ? 'status-badge-blue'
                    : 'status-badge-teal'
                }`}>
                  {fishItem.water_type}
                </span>
              </div>
            </div>
            
            <div className="mobile-card-actions">
              <button
                onClick={() => handleViewFish(fishItem)}
                className="mobile-action-btn mobile-action-btn-primary"
                title="View Details"
              >
                <EyeIcon className="h-4 w-4 mr-1" />
                View
              </button>
              <button
                onClick={() => handleEditFish(fishItem)}
                className="mobile-action-btn mobile-action-btn-secondary"
                title="Edit Fish"
              >
                <PencilIcon className="h-4 w-4 mr-1" />
                Edit
              </button>
              <button
                onClick={() => handleToggleStatus(fishItem)}
                className={`mobile-action-btn ${
                  fishItem.active 
                    ? 'mobile-action-btn-danger' 
                    : 'mobile-action-btn-primary'
                }`}
                title={fishItem.active ? 'Deactivate' : 'Activate'}
              >
                {fishItem.active ? (
                  <>
                    <XCircleIcon className="h-4 w-4 mr-1" />
                    Deactivate
                  </>
                ) : (
                  <>
                    <CheckCircleIcon className="h-4 w-4 mr-1" />
                    Activate
                  </>
                )}
              </button>
            </div>
          </div>
        ))}
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

      {/* Bulk Upload Modal */}
      {showBulkUpload && (
        <BulkUploadModal
          isOpen={showBulkUpload}
          onUpload={handleBulkUpload}
          onClose={() => setShowBulkUpload(false)}
        />
      )}

      {/* Status Confirmation Dialog */}
      {showStatusDialog && (
        <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
          <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
            <div className="mt-3 text-center">
              <div className="mx-auto flex items-center justify-center h-12 w-12 rounded-full bg-yellow-100">
                <svg className="h-6 w-6 text-yellow-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
                </svg>
              </div>
              <h3 className="text-lg font-medium text-gray-900 mt-2">
                {newStatus ? 'Activate Fish Species' : 'Deactivate Fish Species'}
              </h3>
              <div className="mt-2 px-7 py-3">
                <p className="text-sm text-gray-500">
                  Are you sure you want to {newStatus ? 'activate' : 'deactivate'} <strong>{fishToToggle?.common_name}</strong>?
                  {!newStatus && ' This fish will no longer be displayed in the app.'}
                </p>
              </div>
              <div className="items-center px-4 py-3">
                <button
                  onClick={confirmToggleStatus}
                  className={`px-4 py-2 text-white text-base font-medium rounded-md w-full shadow-sm focus:outline-none focus:ring-2 focus:ring-gray-300 ${
                    newStatus ? 'bg-green-600 hover:bg-green-700' : 'bg-red-600 hover:bg-red-700'
                  }`}
                >
                  {newStatus ? 'Activate Fish' : 'Deactivate Fish'}
                </button>
                <button
                  onClick={() => setShowStatusDialog(false)}
                  className="mt-3 px-4 py-2 bg-gray-500 text-white text-base font-medium rounded-md w-full shadow-sm hover:bg-gray-600 focus:outline-none focus:ring-2 focus:ring-gray-300"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default FishManagement;
