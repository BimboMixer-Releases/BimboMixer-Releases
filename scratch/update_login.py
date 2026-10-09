import re
import os

file_path = r"c:\Users\Hp\OneDrive\Documenti\Sviluppo\contabile\contabile_app\lib\screens\login_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Trovo il metodo build()
build_pattern = re.compile(r"Widget build\(BuildContext context\)\s*\{.*?}", re.DOTALL)
# It's better to just replace the body of the build method up to `void _showRecoveryWizard()`
# The build method goes from `Widget build(BuildContext context) {` to `void _showRecoveryWizard()`

new_build_method = """  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0A10), // Sfondo scuro neon
      body: Stack(
        children: [
          // Sfondo con leggeri gradienti per dare l'effetto neon
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF885CF6).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFEC4899).withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LOGO NEON
                      Center(
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF885CF6).withOpacity(0.6),
                                blurRadius: 40,
                                spreadRadius: -10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset(
                              'assets/images/logo_bimbomixer_neon.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // BENTORNATO
                      const Text(
                        'Bentornato!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Accedi al tuo account per\\ngestire la tua attività in modo semplice.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // NOME UTENTE
                      TextField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Nome utente',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF885CF6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // PASSWORD
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          filled: true,
                          fillColor: Colors.transparent,
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),
                          suffixIcon: const Icon(Icons.visibility_off, color: Colors.white70),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF4A3B69)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF885CF6)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // RICORDA E PASSWORD DIMENTICATA
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Theme(
                                data: Theme.of(context).copyWith(
                                  unselectedWidgetColor: Colors.white54,
                                ),
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (val) {
                                    setState(() {
                                      _rememberMe = val ?? false;
                                    });
                                  },
                                  activeColor: const Color(0xFF885CF6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              Text(
                                'Ricorda',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: _showRecoveryWizard,
                            child: const Text(
                              'Password dimenticata?',
                              style: TextStyle(
                                color: Color(0xFFEC4899),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                      // PULSANTE ACCEDI
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEC4899), Color(0xFF885CF6)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF885CF6).withOpacity(0.5),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text(
                                  'Accedi',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // ACCESSO IMPRONTA
                      if (_isBiometricSupported)
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loginWithBiometrics,
                          icon: const Icon(Icons.fingerprint, color: Colors.white),
                          label: const Text(
                            "Accesso con l'impronta",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Color(0xFF4A3B69)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 32),
                      
                      // REGISTRATI
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            // TODO: Add register logic if exists
                          },
                          child: RichText(
                            text: const TextSpan(
                              text: 'Non hai un account? ',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: 'Registrati',
                                  style: TextStyle(
                                    color: Color(0xFFEC4899),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // ICONS ROW
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.lock_outline, color: Color(0xFFEC4899)),
                                const SizedBox(height: 8),
                                const Text('Sicuro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('I tuoi dati protetti', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_queue, color: Color(0xFFEC4899)),
                                const SizedBox(height: 8),
                                const Text('Sincronizzato', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('su tutti i dispositivi', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.bar_chart, color: Color(0xFFEC4899)),
                                const SizedBox(height: 8),
                                const Text('Smart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                Text('Gestisci in mobilità', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
"""

start_idx = content.find("  @override\n  Widget build(BuildContext context) {")
if start_idx == -1:
    start_idx = content.find("  Widget build(BuildContext context) {")

end_idx = content.find("  void _showRecoveryWizard() {")

if start_idx != -1 and end_idx != -1:
    new_content = content[:start_idx] + new_build_method + "\n" + content[end_idx:]
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Sostituito con successo.")
else:
    print("Non trovato.")
