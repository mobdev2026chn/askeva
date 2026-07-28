import React from 'react';
import {
  View, Text, StyleSheet, ScrollView, SafeAreaView, TouchableOpacity,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { AppBar, Icon, Card, Button } from '../components/ui';
import { CURRENT_USER } from '../utils/data';

export default function MyCardScreen() {
  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <AppBar
        title="My Card"
        dark={false}
        left={<Icon name="user" size={24} color={EVA.greenDeep} />}
      />

      <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
        
        {/* Business Card Preview */}
        <LinearGradient
          colors={['#16330D', '#2A6118']}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[styles.businessCard, EVA.shadow]}
        >
          <View style={styles.cardHeader}>
            <View style={styles.logoCircle}>
              <Icon name="zap" size={24} color={EVA.green} />
            </View>
            <Text style={styles.cardBrand}>AskEva</Text>
          </View>
          
          <View style={styles.cardBody}>
            <Text style={styles.cardName}>{CURRENT_USER.name}</Text>
            <Text style={styles.cardRole}>{CURRENT_USER.role}</Text>
            
            <View style={styles.cardDetailsBox}>
              <Text style={styles.cardDetailText}>{CURRENT_USER.company}</Text>
              <Text style={styles.cardDetailText}>{CURRENT_USER.region}</Text>
            </View>
          </View>
        </LinearGradient>

        <View style={styles.shareRow}>
          <Button title="Share via QR" onPress={() => {}} kind="secondary" style={{ flex: 1 }} />
          <Button title="Send Link" onPress={() => {}} style={{ flex: 1 }} />
        </View>

        {/* Contact Details */}
        <Card style={{ padding: 24, marginTop: 32 }}>
          <Text style={styles.sectionTitle}>Contact Information</Text>
          
          <View style={styles.detailRow}>
            <View style={styles.iconBox}><Icon name="mail" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.detailLabel}>Email</Text>
              <Text style={styles.detailText}>{CURRENT_USER.email}</Text>
            </View>
          </View>
          
          <View style={styles.detailRow}>
            <View style={styles.iconBox}><Icon name="phone" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.detailLabel}>Phone</Text>
              <Text style={styles.detailText}>{CURRENT_USER.phone}</Text>
            </View>
          </View>
          
          <View style={styles.detailRow}>
            <View style={styles.iconBox}><Icon name="briefcase" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.detailLabel}>Company</Text>
              <Text style={styles.detailText}>{CURRENT_USER.company}</Text>
            </View>
          </View>

          <View style={styles.detailRow}>
            <View style={styles.iconBox}><Icon name="map-pin" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.detailLabel}>Region</Text>
              <Text style={styles.detailText}>{CURRENT_USER.region}</Text>
            </View>
          </View>
        </Card>

      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20 },
  businessCard: {
    borderRadius: 24, padding: 32, height: 220, justifyContent: 'space-between',
    borderWidth: 1, borderColor: 'rgba(255,255,255,0.1)',
  },
  cardHeader: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  logoCircle: { width: 40, height: 40, borderRadius: 20, backgroundColor: 'rgba(255,255,255,0.1)', justifyContent: 'center', alignItems: 'center' },
  cardBrand: { fontSize: 18, fontWeight: '800', color: '#fff', letterSpacing: 1 },
  cardBody: { marginTop: 'auto' },
  cardName: { fontSize: 24, fontWeight: '800', color: '#fff', letterSpacing: -0.5 },
  cardRole: { fontSize: 14, color: EVA.green, fontWeight: '700', marginTop: 4 },
  cardDetailsBox: { marginTop: 16, gap: 4 },
  cardDetailText: { fontSize: 12, color: 'rgba(255,255,255,0.6)', fontWeight: '500', letterSpacing: 0.5, textTransform: 'uppercase' },
  shareRow: { flexDirection: 'row', gap: 12, marginTop: 24 },
  sectionTitle: { fontSize: 18, fontWeight: '800', color: EVA.ink, marginBottom: 24, letterSpacing: -0.5 },
  detailRow: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 20 },
  iconBox: { width: 40, height: 40, borderRadius: 20, backgroundColor: EVA.greenSoft, justifyContent: 'center', alignItems: 'center' },
  detailLabel: { fontSize: 12, color: EVA.muted, fontWeight: '700', marginBottom: 2 },
  detailText: { fontSize: 15, color: EVA.ink, fontWeight: '600' },
});
