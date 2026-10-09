import sys

with open('lib/services/update_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = r'''    // Save in app-specific external directory to avoid Android scoped storage issues
    Directory? downloadsDir = await getExternalStorageDirectory();
    downloadsDir ??= await getApplicationDocumentsDirectory();'''

replacement = r'''    // Salviamo nella cartella pubblica Download per evitare il problema 
    // "Il pacchetto non  valido" causato dallo Scoped Storage su Android 11+
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!downloadsDir.existsSync()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getDownloadsDirectory();
    }
    downloadsDir ??= await getApplicationDocumentsDirectory();'''

content = content.replace(target, replacement)

with open('lib/services/update_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
