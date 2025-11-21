import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../contexts/AuthContext';
import { Plus, Check, X, Camera, ShoppingCart, ArrowLeft } from 'lucide-react';
import { supabase } from '../lib/supabase';

interface ShoppingItem {
  id: string;
  item_name: string;
  description: string | null;
  photo_url: string | null;
  is_purchased: boolean;
  created_by: string;
  purchased_by: string | null;
  created_at: string;
  purchased_at: string | null;
  profiles?: {
    full_name: string;
  };
  purchaser?: {
    full_name: string;
  };
}

export function ShoppingList({ onBack }: { onBack?: () => void } = {}) {
  const { t: _t } = useTranslation();
  const { profile } = useAuth();
  const [items, setItems] = useState<ShoppingItem[]>([]);
  const [showModal, setShowModal] = useState(false);
  const [formData, setFormData] = useState({
    item_name: '',
    description: '',
  }) as any;
  const [photo, setPhoto] = useState<File | null>(null);
  const [loading, setLoading] = useState(false);

  const isAdmin = profile?.role === 'admin';

  useEffect(() => {
    loadItems();

    const channel = supabase
      .channel(`shopping_items_${Date.now()}`)
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'shopping_items',
        },
        () => {
          loadItems();
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, []);

  const loadItems = async () => {
    try {
      const { data, error } = await supabase
        .from('shopping_items')
        .select(`
          *,
          profiles:created_by(full_name),
          purchaser:purchased_by(full_name)
        `)
        .order('is_purchased', { ascending: true })
        .order('created_at', { ascending: false }) as any;

      if (error) throw error;
      setItems(data || []);
    } catch (error) {
      console.error('Error loading shopping items:', error);
    }
  };

  const uploadPhoto = async (file: File): Promise<string> => {
    const fileExt = file.name.split('.').pop();
    const fileName = `${Math.random()}.${fileExt}`;
    const filePath = `shopping/${fileName}`;

    const { error: uploadError } = await supabase.storage
      .from('task-photos')
      .upload(filePath, file);

    if (uploadError) {
      console.error('Upload error:', uploadError);
      return '';
    }

    const { data } = supabase.storage.from('task-photos').getPublicUrl(filePath);
    return data.publicUrl;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      let photoUrl = null;
      if (photo) {
        photoUrl = await uploadPhoto(photo);
      }

      const { error } = await supabase.from('shopping_items').insert({
        item_name: formData.item_name,
        description: formData.description || null,
        photo_url: photoUrl,
        created_by: profile?.id,
      }) as any;

      if (error) throw error;

      setShowModal(false);
      setFormData({ item_name: '', description: '' }) as any;
      setPhoto(null);
    } catch (error) {
      console.error('Error adding item:', error);
      alert('Error adding item');
    } finally {
      setLoading(false);
    }
  };

  const handleTogglePurchased = async (item: ShoppingItem) => {
    try {
      const { error } = await supabase
        .from('shopping_items')
        .update({
          is_purchased: !item.is_purchased,
          purchased_by: !item.is_purchased ? profile?.id : null,
          purchased_at: !item.is_purchased ? new Date().toISOString() : null,
        })
        .eq('id', item.id);

      if (error) throw error;
    } catch (error) {
      console.error('Error updating item:', error);
    }
  };

  const handleDelete = async (itemId: string) => {
    if (!confirm('Delete this item?')) return;

    try {
      const { error } = await supabase
        .from('shopping_items')
        .delete()
        .eq('id', itemId);

      if (error) throw error;
    } catch (error) {
      console.error('Error deleting item:', error);
    }
  };

  const pendingItems = items.filter((item) => !item.is_purchased);
  const purchasedItems = items.filter((item) => item.is_purchased);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          {onBack && (
            <button
              onClick={onBack}
              className="p-2 hover:bg-beige-100 rounded-lg transition-colors"
            >
              <ArrowLeft className="w-6 h-6 text-gray-700" />
            </button>
          )}
          <div>
            <h2 className="text-3xl font-bold text-gray-900">Shopping List</h2>
            <p className="text-gray-600 mt-1">Add items that need to be purchased</p>
          </div>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Plus className="w-5 h-5" />
          <span>Add Item</span>
        </button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div>
          <div className="flex items-center space-x-2 mb-4">
            <ShoppingCart className="w-5 h-5 text-gray-700" />
            <h3 className="text-xl font-bold text-gray-900">Need to Buy ({pendingItems.length})</h3>
          </div>
          <div className="space-y-3">
            {pendingItems.map((item) => (
              <div
                key={item.id}
                className="bg-white rounded-xl p-4 shadow-sm border-2 border-orange-200 hover:border-orange-400 transition-all"
              >
                <div className="flex items-start justify-between mb-2">
                  <div className="flex-1">
                    <h4 className="text-lg font-semibold text-gray-900">{item.item_name}</h4>
                    {item.description && (
                      <p className="text-sm text-gray-600 mt-1">{item.description}</p>
                    )}
                    <p className="text-xs text-gray-500 mt-2">
                      Added by {item.profiles?.full_name} on{' '}
                      {item.created_at ? new Date(item.created_at) : new Date().toLocaleDateString()}
                    </p>
                  </div>
                  <div className="flex items-center space-x-2 ml-3">
                    <button
                      onClick={() => handleTogglePurchased(item)}
                      className="p-2 bg-green-100 text-green-700 rounded-lg hover:bg-green-200 transition-colors"
                      title="Mark as purchased"
                    >
                      <Check className="w-5 h-5" />
                    </button>
                    {isAdmin && (
                      <button
                        onClick={() => handleDelete(item.id)}
                        className="p-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
                        title="Delete item"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    )}
                  </div>
                </div>
                {item.photo_url && (
                  <img
                    src={item.photo_url}
                    alt={item.item_name}
                    className="rounded-lg max-w-full h-48 object-cover mt-3"
                  />
                )}
              </div>
            ))}
            {pendingItems.length === 0 && (
              <div className="text-center py-12 bg-gray-50 rounded-xl">
                <ShoppingCart className="w-12 h-12 text-gray-400 mx-auto mb-3" />
                <p className="text-gray-600">No items to buy</p>
              </div>
            )}
          </div>
        </div>

        <div>
          <div className="flex items-center space-x-2 mb-4">
            <Check className="w-5 h-5 text-green-700" />
            <h3 className="text-xl font-bold text-gray-900">Purchased ({purchasedItems.length})</h3>
          </div>
          <div className="space-y-3">
            {purchasedItems.map((item) => (
              <div
                key={item.id}
                className="bg-white rounded-xl p-4 shadow-sm border-2 border-green-200 opacity-75"
              >
                <div className="flex items-start justify-between mb-2">
                  <div className="flex-1">
                    <h4 className="text-lg font-semibold text-gray-900 line-through">
                      {item.item_name}
                    </h4>
                    {item.description && (
                      <p className="text-sm text-gray-600 mt-1">{item.description}</p>
                    )}
                    <p className="text-xs text-gray-500 mt-2">
                      Purchased by {item.purchaser?.full_name} on{' '}
                      {item.purchased_at && new Date(item.purchased_at).toLocaleDateString()}
                    </p>
                  </div>
                  <div className="flex items-center space-x-2 ml-3">
                    <button
                      onClick={() => handleTogglePurchased(item)}
                      className="p-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors"
                      title="Mark as not purchased"
                    >
                      <X className="w-5 h-5" />
                    </button>
                    {isAdmin && (
                      <button
                        onClick={() => handleDelete(item.id)}
                        className="p-2 bg-red-100 text-red-700 rounded-lg hover:bg-red-200 transition-colors"
                        title="Delete item"
                      >
                        <X className="w-5 h-5" />
                      </button>
                    )}
                  </div>
                </div>
                {item.photo_url && (
                  <img
                    src={item.photo_url}
                    alt={item.item_name}
                    className="rounded-lg max-w-full h-48 object-cover mt-3"
                  />
                )}
              </div>
            ))}
            {purchasedItems.length === 0 && (
              <div className="text-center py-12 bg-gray-50 rounded-xl">
                <Check className="w-12 h-12 text-gray-400 mx-auto mb-3" />
                <p className="text-gray-600">No purchased items</p>
              </div>
            )}
          </div>
        </div>
      </div>

      {showModal && (
        <div
          className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center p-4 z-50"
          onClick={() => {
            setShowModal(false);
          }}
        >
          <div
            className="bg-white rounded-xl p-6 w-full max-w-md"
            onClick={(e) => e.stopPropagation()}
          >
            <h3 className="text-xl font-bold text-gray-900 mb-4">Add Shopping Item</h3>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Item Name *
                </label>
                <input
                  type="text"
                  value={formData.item_name}
                  onChange={(e) => setFormData({ ...formData, item_name: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  placeholder="e.g., Toilet paper, Coffee, etc."
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Description (optional)
                </label>
                <textarea
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                  className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  rows={3}
                  placeholder="Additional details about the item..."
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-1">
                  Photo (optional)
                </label>
                <div className="flex items-center space-x-2">
                  <input
                    type="file"
                    accept="image/*"
                    onChange={(e) => setPhoto(e.target.files?.[0] || null)}
                    className="w-full px-3 py-2 border border-gray-300 rounded-lg"
                  />
                  <Camera className="w-5 h-5 text-gray-400" />
                </div>
                <p className="text-xs text-gray-500 mt-1">
                  Add a photo if you don't know the exact name
                </p>
              </div>
              <div className="flex space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => {
                    setShowModal(false);
                    setFormData({ item_name: '', description: '' }) as any;
                    setPhoto(null);
                  }}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50"
                  disabled={loading}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="flex-1 px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50"
                  disabled={loading}
                >
                  {loading ? 'Adding...' : 'Add Item'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
