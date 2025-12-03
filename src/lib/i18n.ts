import i18n from "i18next";
import { initReactI18next } from "react-i18next";

// Importiere die Übersetzungen direkt aus den Dateien
import de from "../locales/de/translation.json";
import en from "../locales/en/translation.json";
import km from "../locales/km/translation.json";

i18n
  .use(initReactI18next)
  .init({
    resources: {
      de: { translation: de },
      en: { translation: en },
      km: { translation: km },
    },
    lng: "de", // Standard-Sprache
    fallbackLng: "en",
    interpolation: {
      escapeValue: false,
    },
    react: {
      useSuspense: false,
    },
  });

export default i18n;
