import { useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Html5Qrcode } from 'html5-qrcode';
import { X, Camera } from 'lucide-react';

interface QRScannerProps {
  onScan: (result: string) => void;
  onClose: () => void;
}

export function QRScanner({ onScan, onClose }: QRScannerProps) {
  const { t } = useTranslation();
  const scannerRef = useRef<Html5Qrcode | null>(null);
  const [error, setError] = useState<string>('');
  const [isScanning, setIsScanning] = useState(false);

  useEffect(() => {
    const scanner = new Html5Qrcode('qr-reader');
    scannerRef.current = scanner;

    const config = {
      fps: 10,
      qrbox: { width: 250, height: 250 },
      aspectRatio: 1.0,
    };

    scanner
      .start(
        { facingMode: 'environment' },
        config,
        (decodedText) => {
          scanner.stop().then(() => {
            onScan(decodedText);
          }) as any;
        },
        () => {
        }
      )
      .then(() => {
        setIsScanning(true);
        setError('');
      })
      .catch((err) => {
        console.error('Scanner error:', err);
        setError('Kamera-Zugriff verweigert oder nicht verfügbar');
      }) as any;

    return () => {
      if (scanner.isScanning) {
        scanner.stop().catch((err) => console.error('Error stopping scanner:', err));
      }
    };
  }, [onScan]);

  const handleClose = () => {
    if (scannerRef.current && scannerRef.current.isScanning) {
      scannerRef.current.stop().then(() => {
        onClose();
      }) as any;
    } else {
      onClose();
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center p-4 z-50"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-xl p-6 w-full max-w-md"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-2">
            <Camera className="w-6 h-6 text-orange-600" />
            <h3 className="text-xl font-bold text-gray-900">QR Code Scannen</h3>
          </div>
          <button
            onClick={handleClose}
            className="p-2 rounded-lg hover:bg-gray-100 transition-colors"
          >
            <X className="w-6 h-6 text-gray-600" />
          </button>
        </div>

        {error && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <p className="text-sm text-red-800">{error}</p>
            <p className="text-xs text-red-600 mt-1">
              Bitte erlaube Kamera-Zugriff in deinem Browser
            </p>
          </div>
        )}

        <div
          id="qr-reader"
          className="w-full rounded-lg overflow-hidden"
          style={{ minHeight: '300px' }}
        />

        {isScanning && (
          <div className="mt-4 text-center">
            <p className="text-sm text-gray-600">
              Richte die Kamera auf den QR Code
            </p>
            <div className="mt-3 flex items-center justify-center space-x-2">
              <div className="w-2 h-2 bg-orange-500 rounded-full animate-pulse" />
              <span className="text-xs text-orange-600 font-medium">Scanning...</span>
            </div>
          </div>
        )}

        <button
          onClick={handleClose}
          className="w-full mt-4 px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
        >
          Abbrechen
        </button>
      </div>
    </div>
  );
}
