import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TextInput,
  TouchableOpacity,
  Dimensions,
  SafeAreaView,
  StatusBar,
  Image,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { Icon } from '../components/ui';

const { height } = Dimensions.get('window');

export default function LoginScreen({ navigation }: any) {
  const [mode, setMode] = useState<'password' | 'otp'>('password');
  const [id, setId] = useState('staff@askeva.com');
  const [pwd, setPwd] = useState('1234567');
  const [phone, setPhone] = useState('+91 98765 43210');
  const [showPwd, setShowPwd] = useState(false);

  const handleSubmit = () => {
    navigation.replace('Main');
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <StatusBar barStyle="dark-content" backgroundColor={EVA.canvas} />
      <ScrollView style={{ flex: 1 }} contentContainerStyle={{ flexGrow: 1 }} keyboardShouldPersistTaps="handled">
        <View style={styles.container}>
          {/* Header / Brand */}
          <View style={styles.headerSection}>
            <Image
              source={require('../../assets/askeva-logo.png')}
              style={styles.logoImage}
              resizeMode="contain"
            />
            <View style={{ marginTop: 8 }}>
              <Text style={styles.subtitle}>BUSINESS CARD CAPTURE</Text>
            </View>
          </View>

          {/* Card Panel */}
          <View style={styles.card}>
            <Text style={styles.title}>Welcome back</Text>
            <Text style={styles.description}>
              Sign in to capture business cards into your Lead page.
            </Text>

            {/* Mode Switcher */}
            <View style={styles.modeSwitcher}>
              {[
                { k: 'password', l: 'Password' },
                { k: 'otp', l: 'OTP' },
              ].map((t) => (
                <TouchableOpacity
                  key={t.k}
                  onPress={() => setMode(t.k as 'password' | 'otp')}
                  style={[styles.modeButton, mode === t.k && styles.modeButtonActive]}
                  activeOpacity={0.7}
                >
                  {mode === t.k ? (
                    <LinearGradient
                      colors={EVA.greenGradient}
                      start={{ x: 0, y: 0 }}
                      end={{ x: 1, y: 0 }}
                      style={styles.modeButtonInner}
                    >
                      <Text style={[styles.modeButtonText, styles.modeButtonTextActive]}>{t.l}</Text>
                    </LinearGradient>
                  ) : (
                    <View style={styles.modeButtonInner}>
                      <Text style={styles.modeButtonText}>{t.l}</Text>
                    </View>
                  )}
                </TouchableOpacity>
              ))}
            </View>

            {/* Form Fields */}
            <View style={styles.fieldsContainer}>
              {mode === 'password' ? (
                <>
                  <View style={styles.fieldWrapper}>
                    <Text style={styles.fieldLabel}>Email address</Text>
                    <View style={styles.inputRow}>
                      <Icon name="mail" size={18} color={EVA.muted} />
                      <TextInput
                        style={styles.input}
                        value={id}
                        onChangeText={setId}
                        placeholder="you@company.com"
                        placeholderTextColor={EVA.muted}
                        keyboardType="email-address"
                        autoCapitalize="none"
                      />
                    </View>
                  </View>

                  <View style={styles.fieldWrapper}>
                    <Text style={styles.fieldLabel}>Password</Text>
                    <View style={styles.inputRow}>
                      <Icon name="settings" size={18} color={EVA.muted} />
                      <TextInput
                        style={styles.input}
                        value={pwd}
                        onChangeText={setPwd}
                        placeholder="••••••••"
                        placeholderTextColor={EVA.muted}
                        secureTextEntry={!showPwd}
                      />
                      <TouchableOpacity onPress={() => setShowPwd(!showPwd)} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
                        <Icon name="eye" size={18} color={EVA.muted} />
                      </TouchableOpacity>
                    </View>
                  </View>

                  <TouchableOpacity style={{ alignSelf: 'flex-end' }}>
                    <Text style={styles.forgotPassword}>Forgot password?</Text>
                  </TouchableOpacity>
                </>
              ) : (
                <>
                  <View style={styles.fieldWrapper}>
                    <Text style={styles.fieldLabel}>Phone Number</Text>
                    <View style={styles.inputRow}>
                      <Icon name="phone" size={18} color={EVA.muted} />
                      <TextInput
                        style={styles.input}
                        value={phone}
                        onChangeText={setPhone}
                        placeholder="+91 00000 00000"
                        placeholderTextColor={EVA.muted}
                        keyboardType="phone-pad"
                      />
                    </View>
                  </View>
                  <Text style={styles.otpHint}>
                    We'll text you a 6-digit code to verify it's you.
                  </Text>
                </>
              )}
            </View>

            {/* Submit Button */}
            <TouchableOpacity onPress={handleSubmit} activeOpacity={0.85} style={styles.submitButtonContainer}>
              <LinearGradient
                colors={EVA.greenGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.submitButton}
              >
                <Text style={styles.submitButtonText}>
                  {mode === 'otp' ? 'Send Code' : 'Sign In'}
                </Text>
              </LinearGradient>
            </TouchableOpacity>

            {/* Divider */}
            <View style={styles.divider}>
              <View style={styles.dividerLine} />
              <Text style={styles.dividerText}>OR</Text>
              <View style={styles.dividerLine} />
            </View>

            {/* SSO */}
            <TouchableOpacity style={styles.ssoButton} activeOpacity={0.7}>
              <Icon name="building" size={18} color={EVA.greenDeep} />
              <Text style={styles.ssoButtonText}>Continue with SSO</Text>
            </TouchableOpacity>
          </View>

          <Text style={styles.version}>v2.4.1 · AskEva Internal</Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 24,
    paddingTop: 48,
    paddingBottom: 32,
    justifyContent: 'center',
    gap: 32,
  },
  headerSection: {
    alignItems: 'center',
  },
  logoImage: {
    width: 140,
    height: 140,
  },
  subtitle: {
    fontSize: 11,
    fontWeight: '700',
    color: EVA.muted,
    letterSpacing: 2,
    textAlign: 'center',
    marginTop: 4,
  },
  card: {
    backgroundColor: EVA.surface,
    borderRadius: 28,
    padding: 28,
    gap: 20,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.06,
    shadowRadius: 24,
    elevation: 4,
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.03)',
  },
  title: {
    fontSize: 24,
    fontWeight: '800',
    color: EVA.ink,
    letterSpacing: -0.6,
  },
  description: {
    fontSize: 15,
    color: EVA.muted,
    lineHeight: 22,
    fontWeight: '500',
    marginTop: -8,
  },
  modeSwitcher: {
    flexDirection: 'row',
    backgroundColor: EVA.canvas,
    borderRadius: 16,
    padding: 4,
    gap: 4,
  },
  modeButton: {
    flex: 1,
    borderRadius: 12,
    overflow: 'hidden',
  },
  modeButtonActive: {},
  modeButtonInner: {
    paddingVertical: 12,
    alignItems: 'center',
    borderRadius: 12,
  },
  modeButtonText: {
    fontSize: 14,
    fontWeight: '700',
    color: EVA.muted,
  },
  modeButtonTextActive: {
    color: '#fff',
  },
  fieldsContainer: {
    gap: 16,
  },
  fieldWrapper: {
    gap: 8,
  },
  fieldLabel: {
    fontSize: 13,
    color: EVA.body,
    fontWeight: '700',
    letterSpacing: 0.1,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: EVA.canvas,
    borderWidth: 1.5,
    borderColor: EVA.hairline,
    borderRadius: 14,
    paddingVertical: 14,
    paddingHorizontal: 16,
    gap: 12,
  },
  input: {
    flex: 1,
    color: EVA.ink,
    fontSize: 15,
    fontWeight: '500',
  },
  forgotPassword: {
    fontSize: 13,
    color: EVA.greenDeep,
    fontWeight: '700',
  },
  otpHint: {
    fontSize: 13,
    color: EVA.muted,
    lineHeight: 20,
    fontWeight: '500',
  },
  submitButtonContainer: {
    borderRadius: 16,
    overflow: 'hidden',
    shadowColor: EVA.green,
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.3,
    shadowRadius: 12,
    elevation: 4,
  },
  submitButton: {
    paddingVertical: 18,
    alignItems: 'center',
  },
  submitButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '800',
    letterSpacing: 0.3,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: EVA.hairline,
  },
  dividerText: {
    fontSize: 12,
    color: EVA.muted,
    fontWeight: '700',
    letterSpacing: 1,
  },
  ssoButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    backgroundColor: EVA.greenSoft,
    borderWidth: 1.5,
    borderColor: 'rgba(88,197,54,0.2)',
    borderRadius: 14,
    paddingVertical: 14,
  },
  ssoButtonText: {
    color: EVA.greenDeep,
    fontSize: 15,
    fontWeight: '700',
  },
  version: {
    fontSize: 12,
    color: EVA.muted,
    textAlign: 'center',
    fontWeight: '500',
  },
});
