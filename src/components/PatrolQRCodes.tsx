import { useEffect, useState } from 'react';

import { Shield, Download } from 'lucide-react';
import { supabase } from '../lib/supabase';
import QRCode from 'qrcode';

interface PatrolLocation {
  id: string;
  name: string;
  qr_code: string;
  description: string;
  order_index: number;
}

export function PatrolQRCodes({}: { onBack?: () => void } = {}) {
  const [locations, setLocations] = useState<PatrolLocation[]>([]);
  const [qrCodeURLs, setQrCodeURLs] = useState<{ [key: string]: string }>({}) as any;

  useEffect(() => {
    loadLocations();
  }, []);

  useEffect(() => {
    locations.forEach((location) => {
      generateQRCode(location.qr_code, location.id);
    }) as any;
  }, [locations]);

  const loadLocations = async () => {
    const { data, error } = await supabase
      .from('patrol_locations')
      .select('*')
      .order('order_index');

    if (error) {
      console.error('Error loading locations:', error);
      return;
    }

    setLocations(data || []);
  };

  const generateQRCode = async (text: string, locationId: string) => {
    try {
      const url = await QRCode.toDataURL(text, {
        width: 400,
        margin: 2,
        color: {
          dark: '#000000',
          light: '#FFFFFF',
        },
      }) as any;
      setQrCodeURLs((prev: any) => ({ ...prev, [locationId]: url }));
    } catch (error) {
      console.error('Error generating QR code:', error);
    }
  };

  const downloadQRCode = (locationId: string, locationName: string) => {
    const url = qrCodeURLs[locationId];
    if (!url) return;

    const link = document.createElement('a');
    link.href = url;
    link.download = `patrol-qr-${locationName.toLowerCase().replace(/\s+/g, '-')}.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const downloadAllQRCodes = () => {
    locations.forEach((location) => {
      setTimeout(() => {
        downloadQRCode(location.id, location.name);
      }, location.order_index * 500);
    }) as any;
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-3xl font-bold text-gray-900">Patrol QR Codes</h2>
          <p className="text-gray-600 mt-1">Print and place these QR codes at each location</p>
        </div>
        <button
          onClick={downloadAllQRCodes}
          className="flex items-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
        >
          <Download className="w-5 h-5" />
          <span>Download All</span>
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {locations.map((location) => (
          <div key={location.id} className="bg-white rounded-xl p-6 shadow-sm border border-gray-200">
            <div className="flex items-center space-x-3 mb-4">
              <Shield className="w-6 h-6 text-blue-600" />
              <h3 className="text-lg font-bold text-gray-900">{location.name}</h3>
            </div>

            <div className="bg-gray-50 rounded-lg p-4 mb-4">
              <p className="text-sm text-gray-700">{location.description}</p>
            </div>

            {qrCodeURLs[location.id] && (
              <div className="bg-white p-4 rounded-lg border-2 border-gray-200 mb-4">
                <img
                  src={qrCodeURLs[location.id]}
                  alt={`QR Code for ${location.name}`}
                  className="w-full"
                />
              </div>
            )}

            <div className="bg-blue-50 rounded-lg p-3 mb-4">
              <p className="text-xs text-blue-900 font-mono break-all">{location.qr_code}</p>
            </div>

            <button
              onClick={() => downloadQRCode(location.id, location.name)}
              className="w-full flex items-center justify-center space-x-2 bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors"
            >
              <Download className="w-4 h-4" />
              <span>Download QR Code</span>
            </button>
          </div>
        ))}
      </div>

      <div className="bg-yellow-50 border-2 border-yellow-200 rounded-xl p-6">
        <h3 className="text-lg font-bold text-yellow-900 mb-3">Installation Instructions</h3>
        <ol className="list-decimal list-inside space-y-2 text-yellow-900">
          <li>Download the QR codes using the buttons above</li>
          <li>Print each QR code on waterproof paper or laminate them</li>
          <li>Place the QR codes at eye level in each location:
            <ul className="list-disc list-inside ml-6 mt-1 space-y-1">
              <li><strong>Entrance Area:</strong> Near the main entrance door</li>
              <li><strong>Pool Area:</strong> Near the pool equipment or entrance gate</li>
              <li><strong>Staircase:</strong> At the top or bottom of the stairs</li>
            </ul>
          </li>
          <li>Ensure QR codes are clearly visible and not obstructed</li>
          <li>Test scanning with the mobile app before finalizing placement</li>
        </ol>
      </div>

      <div className="bg-blue-50 border-2 border-blue-200 rounded-xl p-6">
        <h3 className="text-lg font-bold text-blue-900 mb-3">How It Works</h3>
        <ul className="space-y-2 text-blue-900">
          <li className="flex items-start space-x-2">
            <span className="font-bold">•</span>
            <span>Staff scan QR codes during their assigned patrol rounds</span>
          </li>
          <li className="flex items-start space-x-2">
            <span className="font-bold">•</span>
            <span>Rounds occur every 75 minutes starting at 11:00 AM</span>
          </li>
          <li className="flex items-start space-x-2">
            <span className="font-bold">•</span>
            <span>15-minute grace period before and after each time slot</span>
          </li>
          <li className="flex items-start space-x-2">
            <span className="font-bold">•</span>
            <span>Each successful scan awards +1 point</span>
          </li>
          <li className="flex items-start space-x-2">
            <span className="font-bold">•</span>
            <span>Missed scans result in -1 point</span>
          </li>
          <li className="flex items-start space-x-2">
            <span className="font-bold">•</span>
            <span>Random photo requests (30% chance) for quality verification</span>
          </li>
        </ul>
      </div>
    </div>
  );
}
