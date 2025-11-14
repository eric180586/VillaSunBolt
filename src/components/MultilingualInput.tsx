import { useState, useEffect } from 'react';
import { Globe } from 'lucide-react';
import { useTranslation } from 'react-i18next';

interface MultilingualInputProps {
  value_de?: string;
  value_en?: string;
  value_km?: string;
  onChange: (values: { de: string; en: string; km: string }) => void;
  label: string;
  type?: 'text' | 'textarea';
  required?: boolean;
  placeholder?: string;
}

export function MultilingualInput({
  value_de = '',
  value_en = '',
  value_km = '',
  onChange,
  label,
  type = 'text',
  required = false,
  placeholder = ''
}: MultilingualInputProps) {
  const { t, i18n } = useTranslation();
  const [expanded, setExpanded] = useState(false);
  const [values, setValues] = useState({
    de: value_de,
    en: value_en,
    km: value_km
  });

  useEffect(() => {
    setValues({
      de: value_de,
      en: value_en,
      km: value_km
    });
  }, [value_de, value_en, value_km]);

  const currentLang = i18n.language;

  const handleChange = (lang: 'de' | 'en' | 'km', value: string) => {
    const newValues = { ...values, [lang]: value };
    setValues(newValues);
    onChange(newValues);
  };

  const InputComponent = type === 'textarea' ? 'textarea' : 'input';
  const inputClasses = type === 'textarea'
    ? "w-full p-2 border border-gray-300 rounded resize-none"
    : "w-full p-2 border border-gray-300 rounded";

  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <label className="block text-sm font-medium text-gray-700">
          {label}
        </label>
        <button
          type="button"
          onClick={() => setExpanded(!expanded)}
          className="flex items-center gap-1 text-xs text-blue-600 hover:text-blue-800"
        >
          <Globe className="w-4 h-4" />
          {expanded ? t('common.hideOtherLanguages') : t('common.showAllLanguages')}
        </button>
      </div>

      <div>
        <div className="text-xs text-gray-500 mb-1">
          {currentLang === 'de' && '🇩🇪 Deutsch'}
          {currentLang === 'en' && '🇬🇧 English'}
          {currentLang === 'km' && '🇰🇭 ខ្មែរ'}
        </div>
        <InputComponent
          className={inputClasses}
          value={values[currentLang as 'de' | 'en' | 'km']}
          onChange={(e: any) => handleChange(currentLang as 'de' | 'en' | 'km', e.target.value)}
          placeholder={placeholder}
          required={required}
          rows={type === 'textarea' ? 3 : undefined}
        />
      </div>

      {expanded && (
        <div className="space-y-3 pl-4 border-l-2 border-gray-200">
          {currentLang !== 'de' && (
            <div>
              <div className="text-xs text-gray-500 mb-1">🇩🇪 Deutsch</div>
              <InputComponent
                className={inputClasses}
                value={values.de}
                onChange={(e: any) => handleChange('de', e.target.value)}
                placeholder={placeholder}
                rows={type === 'textarea' ? 3 : undefined}
              />
            </div>
          )}

          {currentLang !== 'en' && (
            <div>
              <div className="text-xs text-gray-500 mb-1">🇬🇧 English</div>
              <InputComponent
                className={inputClasses}
                value={values.en}
                onChange={(e: any) => handleChange('en', e.target.value)}
                placeholder={placeholder}
                rows={type === 'textarea' ? 3 : undefined}
              />
            </div>
          )}

          {currentLang !== 'km' && (
            <div>
              <div className="text-xs text-gray-500 mb-1">🇰🇭 ខ្មែរ</div>
              <InputComponent
                className={inputClasses}
                value={values.km}
                onChange={(e: any) => handleChange('km', e.target.value)}
                placeholder={placeholder}
                rows={type === 'textarea' ? 3 : undefined}
              />
            </div>
          )}
        </div>
      )}

      {!expanded && (
        <p className="text-xs text-gray-500">
          {t('common.clickToAddOtherLanguages')}
        </p>
      )}
    </div>
  );
}
