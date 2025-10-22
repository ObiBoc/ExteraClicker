#!/usr/bin/env bash

# Скрипт для генерации файла manifest.json для игровых ассетов (или любых других файлов).
# Требует установки утилиты 'jq' для работы с JSON.

# --- КОНФИГУРАЦИЯ ---
# Директория для сканирования (по умолчанию - текущая директория)
SCAN_DIR="."
# Имя выходного файла манифеста
OUTPUT_FILE="manifest.json"
# --------------------

echo "Проверка зависимостей..."
# Проверка, установлен ли jq
if ! command -v jq &> /dev/null
then
    echo "Ошибка: утилита 'jq' не установлена."
    echo "Пожалуйста, установите ее. Примеры команд:"
    echo "  - Для Linux (Debian/Ubuntu): sudo apt install jq"
    echo "  - Для macOS (Homebrew): brew install jq"
    echo "  - Для Termux: pkg install jq"
    exit 1
fi

if ! command -v sha256sum &> /dev/null
then
    echo "Ошибка: утилита 'sha256sum' не найдена."
    echo "Для Linux/Termux она обычно есть. Для macOS попробуйте 'gsha256sum' (из coreutils)."
    exit 1
fi

echo "✅ Зависимости в порядке."
echo "Начало генерации манифеста из директории '$SCAN_DIR'..."

# Используем временный файл для хранения отдельных JSON-объектов
TEMP_JSON_LIST=$(mktemp)
if [ $? -ne 0 ]; then
    echo "Ошибка: Не удалось создать временный файл."
    exit 1
fi

# Находим все обычные файлы, исключая сам файл манифеста
# Используем -print0 и read -r -d $'\0' для безопасной обработки имен с пробелами/спецсимволами.
find "$SCAN_DIR" -type f ! -name "$(basename "$OUTPUT_FILE")" -print0 | while IFS= read -r -d $'\0' file; do
    # Получаем относительный путь (удаляем './' в начале, если есть)
    relative_path="${file#./}"

    # Вычисляем SHA-256 хэш файла
    sha256=$(sha256sum "$file" | awk '{print $1}')

    # Генерируем один JSON-объект и добавляем его во временный список
    jq -n --arg path "$relative_path" --arg sha "$sha256" \
        '{relative_path: $path, sha: $sha}' >> "$TEMP_JSON_LIST"
done

# Читаем поток JSON-объектов из временного файла и объединяем их в один JSON-массив
if [ ! -s "$TEMP_JSON_LIST" ]; then
    echo "Файлы для включения в манифест не найдены. Создается пустой массив."
    echo "[]" > "$OUTPUT_FILE"
else
    # jq -s (slurp): читает все входные данные в один массив
    jq -s '.' "$TEMP_JSON_LIST" > "$OUTPUT_FILE"
fi

# Очищаем временный файл
rm "$TEMP_JSON_LIST"

echo "--------------------------------------------------------"
echo "✅ Манифест успешно сгенерирован!"
echo "Файл: $OUTPUT_FILE"
echo "Полный путь: $(pwd)/$OUTPUT_FILE"
echo "--------------------------------------------------------"

# Отображаем небольшой пример сгенерированного манифеста
echo -e "\n--- Пример сгенерированного манифеста (первые 10 строк) ---"
head -n 10 "$OUTPUT_FILE"
if [ $(wc -l < "$OUTPUT_FILE") -gt 10 ]; then
    echo "..."
fi
echo -e "-----------------------------------------------------------"

# Инструкции по запуску
echo -e "\nИНСТРУКЦИИ:\n1. Сохраните содержимое скрипта в файл, например, 'generate_manifest.sh'."
echo "2. Дайте файлу права на выполнение: chmod +x generate_manifest.sh"
echo "3. Запустите скрипт в терминале (Termux, Linux, macOS) из папки с вашими ассетами: ./generate_manifest.sh"

