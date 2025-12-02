import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import de from "./locales/de/translation.json";
import en from "./locales/en/translation.json";
import km from "./locales/km/translation.json";

i18n
  .use(initReactI18next)
  .init({
    resources: {
      de: { translation: de },
      en: { translation: en },
      km: { translation: km },
    },
    fallbackLng: "de",
    interpolation: { escapeValue: false },
    supportedLngs: ["de", "en", "km"]
  });

export default i18n;
