import React from 'react';
import { View, Text, StyleSheet, Dimensions, TouchableOpacity, ViewStyle, TextStyle } from 'react-native';
import { Feather } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { BlurView } from 'expo-blur';
import { EVA } from '../utils/theme';

const { width } = Dimensions.get('window');

export interface IconProps {
  name: string;
  size?: number;
  color?: string;
}

export const Icon: React.FC<IconProps> = ({ name, size = 20, color = EVA.ink }) => {
  const iconMap: { [key: string]: keyof typeof Feather.glyphMap } = {
    home: 'home',
    users: 'users',
    scan: 'maximize',
    chart: 'bar-chart-2',
    target: 'target',
    user: 'user',
    phone: 'phone',
    mail: 'mail',
    close: 'x',
    check: 'check',
    chevR: 'chevron-right',
    chevL: 'chevron-left',
    eye: 'eye',
    settings: 'settings',
    building: 'briefcase',
    calendar: 'calendar',
    clock: 'clock',
    bell: 'bell',
    edit: 'edit-2',
    note: 'file-text',
    search: 'search',
    filter: 'filter',
    plus: 'plus',
    download: 'download',
    tag: 'tag',
    flash: 'zap',
    image: 'image',
    warn: 'alert-triangle',
    refresh: 'refresh-cw',
    whats: 'message-circle',
    camera: 'camera',
    'arrow-left': 'arrow-left',
    'check-circle': 'check-circle',
    'alert-circle': 'alert-circle',
    map: 'map-pin',
    call: 'phone-call',
    email: 'mail',
    status: 'bookmark',
  };

  const featherName = iconMap[name] || 'circle';

  return <Feather name={featherName} size={size} color={color} />;
};

export interface ButtonProps {
  onPress: () => void;
  title: string;
  kind?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  style?: ViewStyle;
  full?: boolean;
}

export const Button: React.FC<ButtonProps> = ({
  onPress,
  title,
  kind = 'primary',
  size = 'md',
  disabled = false,
  style,
  full = false,
}) => {
  const sizes = {
    sm: { paddingVertical: 10, paddingHorizontal: 16, fontSize: 13 },
    md: { paddingVertical: 14, paddingHorizontal: 20, fontSize: 15 },
    lg: { paddingVertical: 18, paddingHorizontal: 24, fontSize: 17 },
  };

  const containerStyle: ViewStyle = {
    borderRadius: 16,
    width: full ? '100%' : 'auto',
    opacity: disabled ? 0.6 : 1,
    overflow: 'hidden',
    ...style,
  };

  const textStyle: TextStyle = {
    fontWeight: '700',
    fontSize: sizes[size].fontSize,
    textAlign: 'center',
    letterSpacing: 0.3,
  };

  if (kind === 'primary') {
    return (
      <TouchableOpacity onPress={onPress} disabled={disabled} activeOpacity={0.8} style={[containerStyle, EVA.shadow]}>
        <LinearGradient
          colors={EVA.greenGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{ paddingVertical: sizes[size].paddingVertical, paddingHorizontal: sizes[size].paddingHorizontal, alignItems: 'center' }}
        >
          <Text style={[textStyle, { color: '#FFFFFF' }]}>{title}</Text>
        </LinearGradient>
      </TouchableOpacity>
    );
  }

  if (kind === 'secondary') {
    return (
      <TouchableOpacity onPress={onPress} disabled={disabled} activeOpacity={0.7} style={containerStyle}>
        <View style={{
          paddingVertical: sizes[size].paddingVertical,
          paddingHorizontal: sizes[size].paddingHorizontal,
          backgroundColor: EVA.surface,
          borderWidth: 1.5,
          borderColor: EVA.hairline,
          borderRadius: 16,
          alignItems: 'center'
        }}>
          <Text style={[textStyle, { color: EVA.ink }]}>{title}</Text>
        </View>
      </TouchableOpacity>
    );
  }

  return (
    <TouchableOpacity onPress={onPress} disabled={disabled} activeOpacity={0.6} style={[containerStyle, { alignItems: 'center', paddingVertical: sizes[size].paddingVertical }]}>
      <Text style={[textStyle, { color: EVA.green }]}>{title}</Text>
    </TouchableOpacity>
  );
};

export const AppBar: React.FC<{
  title: string;
  left?: React.ReactNode;
  right?: React.ReactNode;
  dark?: boolean;
  sub?: string;
}> = ({ title, left, right, dark = false, sub }) => {
  return (
    <BlurView
      intensity={dark ? 0 : 80}
      tint={dark ? 'dark' : 'light'}
      style={{
        backgroundColor: dark ? EVA.greenInk : 'rgba(255,255,255,0.85)',
        borderBottomWidth: 1,
        borderBottomColor: dark ? 'rgba(255,255,255,0.05)' : 'rgba(0,0,0,0.05)',
        paddingTop: 16,
        paddingBottom: 16,
        paddingHorizontal: 20,
        display: 'flex',
        flexDirection: 'row',
        alignItems: 'center',
        minHeight: 64,
      }}
    >
      <View style={{ width: 40, alignItems: 'flex-start' }}>{left}</View>
      <View style={{ flex: 1, alignItems: 'center' }}>
        <Text
          style={{
            fontSize: 18,
            fontWeight: '700',
            color: dark ? '#fff' : EVA.ink,
            letterSpacing: -0.3,
          }}
          numberOfLines={1}
        >
          {title}
        </Text>
        {sub && (
          <Text
            style={{
              fontSize: 13,
              fontWeight: '500',
              color: dark ? 'rgba(255,255,255,0.6)' : EVA.muted,
              marginTop: 2,
            }}
            numberOfLines={1}
          >
            {sub}
          </Text>
        )}
      </View>
      <View style={{ width: 40, alignItems: 'flex-end', flexDirection: 'row', justifyContent: 'flex-end' }}>
        {right}
      </View>
    </BlurView>
  );
};

export const Card: React.FC<{
  children: React.ReactNode;
  onPress?: () => void;
  style?: ViewStyle;
}> = ({ children, onPress, style }) => {
  const Container = onPress ? TouchableOpacity : View;
  return (
    <Container
      activeOpacity={0.7}
      onPress={onPress}
      style={[
        {
          backgroundColor: EVA.surface,
          borderRadius: 20,
          padding: 20,
          marginBottom: 16,
          borderWidth: 1,
          borderColor: 'rgba(0,0,0,0.03)',
        },
        EVA.shadow,
        style,
      ]}
    >
      {children}
    </Container>
  );
};

export const Chip: React.FC<{ label: string; onPress?: () => void }> = ({ label, onPress }) => {
  const Container = onPress ? TouchableOpacity : View;
  return (
    <Container
      activeOpacity={0.6}
      onPress={onPress}
      style={{
        backgroundColor: EVA.chip,
        borderRadius: 20,
        paddingVertical: 6,
        paddingHorizontal: 14,
        marginRight: 8,
        marginBottom: 8,
        borderWidth: 1,
        borderColor: 'rgba(0,0,0,0.02)',
      }}
    >
      <Text style={{ color: EVA.body, fontSize: 13, fontWeight: '600' }}>{label}</Text>
    </Container>
  );
};
