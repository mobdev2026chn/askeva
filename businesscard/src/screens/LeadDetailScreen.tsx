import React, { useState, useEffect } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity, SafeAreaView,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { AppBar, Icon, Card, Chip, Button } from '../components/ui';
import { Lead } from '../types';
import StorageService from '../utils/storage';

export default function LeadDetailScreen({ route, navigation }: any) {
  const { leadId, lead: passedLead } = route.params || {};
  const [lead, setLead] = useState<Lead | null>(passedLead || null);
  const [isLoading, setIsLoading] = useState(!passedLead);

  useEffect(() => {
    if (passedLead) {
      setLead(passedLead);
    } else if (leadId) {
      const loadLead = async () => {
        try {
          const leads = await StorageService.getLeads();
          const foundLead = leads.find((l) => l.id === leadId);
          if (foundLead) setLead(foundLead);
        } catch (error) {
          console.error('Error loading lead:', error);
        } finally {
          setIsLoading(false);
        }
      };
      loadLead();
    }
  }, [leadId, passedLead]);

  if (isLoading || !lead) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
        <AppBar
          title={isLoading ? 'Loading...' : 'Lead not found'}
          left={
            <TouchableOpacity onPress={() => navigation.goBack()} style={styles.iconButton}>
              <Icon name="arrow-left" size={20} color={EVA.ink} />
            </TouchableOpacity>
          }
        />
      </SafeAreaView>
    );
  }

  const scoreColor = lead.score >= 80 ? EVA.green : lead.score >= 50 ? EVA.warn : EVA.danger;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <AppBar
        title="Contact Details"
        left={
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.iconButton}>
            <Icon name="arrow-left" size={20} color={EVA.ink} />
          </TouchableOpacity>
        }
        right={
          <TouchableOpacity style={styles.iconButton}>
            <Icon name="edit" size={20} color={EVA.greenDeep} />
          </TouchableOpacity>
        }
      />

      <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
        
        {/* Profile Header */}
        <View style={styles.profileHeader}>
          <LinearGradient
            colors={EVA.greenGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.avatarLarge}
          >
            <Text style={styles.avatarTextLarge}>{(lead.name?.[0] || '?').toUpperCase()}</Text>
          </LinearGradient>
          <Text style={styles.profileName}>{lead.name}</Text>
          <Text style={styles.profileRole}>{lead.role}</Text>
          {lead.company && (
            <View style={styles.profileCompany}>
              <Icon name="building" size={14} color={EVA.muted} />
              <Text style={styles.profileCompanyText}>{lead.company}</Text>
            </View>
          )}
        </View>

        {/* Action Buttons */}
        <View style={styles.quickActions}>
          <TouchableOpacity style={styles.quickActionButton} activeOpacity={0.7}>
            <LinearGradient colors={EVA.greenGradient} style={styles.quickActionGradient} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }}>
              <Icon name="phone" size={18} color="#fff" />
              <Text style={styles.quickActionTextPrimary}>Call</Text>
            </LinearGradient>
          </TouchableOpacity>
          <TouchableOpacity style={styles.quickActionButtonSecondary} activeOpacity={0.7}>
            <Icon name="mail" size={18} color={EVA.greenDeep} />
            <Text style={styles.quickActionTextSecondary}>Email</Text>
          </TouchableOpacity>
        </View>

        {/* Score Card */}
        <Card style={styles.scoreCard}>
          <View style={styles.scoreHeader}>
            <View style={[styles.scoreCircle, { borderColor: scoreColor }]}>
              <Text style={[styles.scoreValue, { color: scoreColor }]}>{lead.score}</Text>
            </View>
            <View style={{ flex: 1 }}>
              <Text style={styles.scoreTitle}>Lead Score</Text>
              <Text style={styles.scoreDesc}>Based on profile completion and relevance</Text>
            </View>
          </View>
          <View style={styles.scoreBreakdown}>
            {Object.entries(lead.scoreBreak).map(([key, value]) => (
              <View key={key} style={styles.scoreItem}>
                <Text style={styles.scoreItemLabel}>{key}</Text>
                <Text style={styles.scoreItemValue}>{value}</Text>
              </View>
            ))}
          </View>
        </Card>

        {/* Contact Info */}
        <Card>
          <Text style={styles.sectionTitle}>Contact Information</Text>
          <View style={styles.infoRow}>
            <View style={styles.infoIconBox}><Icon name="mail" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.infoLabel}>Email</Text>
              <Text style={styles.infoText}>{lead.email || 'Not provided'}</Text>
            </View>
          </View>
          <View style={styles.infoRow}>
            <View style={styles.infoIconBox}><Icon name="phone" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.infoLabel}>Phone</Text>
              <Text style={styles.infoText}>{lead.phone || 'Not provided'}</Text>
            </View>
          </View>
          <View style={styles.infoRow}>
            <View style={styles.infoIconBox}><Icon name="map" size={16} color={EVA.greenDeep} /></View>
            <View style={{ flex: 1 }}>
              <Text style={styles.infoLabel}>Location</Text>
              <Text style={styles.infoText}>{lead.location || 'Not provided'}</Text>
            </View>
          </View>
        </Card>

        {/* Tags */}
        {lead.tags.length > 0 && (
          <Card>
            <Text style={styles.sectionTitle}>Tags</Text>
            <View style={styles.tagsRow}>
              {lead.tags.map((tag) => <Chip key={tag} label={tag} />)}
            </View>
          </Card>
        )}

        {/* Notes */}
        {lead.note && (
          <Card>
            <Text style={styles.sectionTitle}>Notes</Text>
            <Text style={styles.noteText}>{lead.note}</Text>
          </Card>
        )}

        {/* Activity */}
        {lead.activity.length > 0 && (
          <Card style={{ padding: 0, overflow: 'hidden' }}>
            <View style={{ padding: 20, paddingBottom: 8 }}>
              <Text style={styles.sectionTitle}>Activity</Text>
            </View>
            {lead.activity.map((activity, idx) => (
              <View key={idx} style={[styles.activityItem, idx !== lead.activity.length - 1 && styles.activityBorder]}>
                <View style={styles.activityIcon}>
                  <Icon name={activity.k === 'scan' ? 'camera' : activity.k === 'email' ? 'mail' : 'check'} size={14} color={EVA.greenDeep} />
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.activityText}>{activity.text}</Text>
                  <Text style={styles.activityTime}>{activity.t}</Text>
                </View>
              </View>
            ))}
          </Card>
        )}

        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20 },
  iconButton: {
    width: 40, height: 40, borderRadius: 20, backgroundColor: EVA.surface,
    justifyContent: 'center', alignItems: 'center',
    shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.05, shadowRadius: 8, elevation: 2,
  },
  profileHeader: { alignItems: 'center', marginBottom: 24, marginTop: 12 },
  avatarLarge: {
    width: 88, height: 88, borderRadius: 44, justifyContent: 'center', alignItems: 'center',
    shadowColor: EVA.green, shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 12, elevation: 4,
  },
  avatarTextLarge: { fontSize: 36, fontWeight: '800', color: '#fff' },
  profileName: { fontSize: 24, fontWeight: '800', color: EVA.ink, marginTop: 16, letterSpacing: -0.5 },
  profileRole: { fontSize: 15, color: EVA.muted, fontWeight: '500', marginTop: 4 },
  profileCompany: { flexDirection: 'row', alignItems: 'center', gap: 6, marginTop: 8 },
  profileCompanyText: { fontSize: 14, color: EVA.body, fontWeight: '600' },
  quickActions: { flexDirection: 'row', gap: 12, marginBottom: 24 },
  quickActionButton: { flex: 1, borderRadius: 16, overflow: 'hidden', shadowColor: EVA.green, shadowOffset: { width: 0, height: 4 }, shadowOpacity: 0.2, shadowRadius: 8, elevation: 3 },
  quickActionGradient: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 14, gap: 8 },
  quickActionTextPrimary: { color: '#fff', fontSize: 15, fontWeight: '700' },
  quickActionButtonSecondary: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', paddingVertical: 14, gap: 8, backgroundColor: EVA.surface, borderRadius: 16, borderWidth: 1, borderColor: EVA.hairline, shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.04, shadowRadius: 8, elevation: 2 },
  quickActionTextSecondary: { color: EVA.greenDeep, fontSize: 15, fontWeight: '700' },
  scoreCard: { backgroundColor: EVA.surface, padding: 24 },
  scoreHeader: { flexDirection: 'row', alignItems: 'center', gap: 16, marginBottom: 20 },
  scoreCircle: { width: 56, height: 56, borderRadius: 28, borderWidth: 3, justifyContent: 'center', alignItems: 'center' },
  scoreValue: { fontSize: 20, fontWeight: '800' },
  scoreTitle: { fontSize: 16, fontWeight: '800', color: EVA.ink },
  scoreDesc: { fontSize: 13, color: EVA.muted, marginTop: 2 },
  scoreBreakdown: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, borderTopWidth: 1, borderTopColor: EVA.hairline, paddingTop: 16 },
  scoreItem: { backgroundColor: EVA.canvas, paddingHorizontal: 12, paddingVertical: 8, borderRadius: 12, flex: 1, minWidth: '30%', alignItems: 'center', borderWidth: 1, borderColor: EVA.hairline },
  scoreItemLabel: { fontSize: 11, color: EVA.muted, fontWeight: '600', marginBottom: 4 },
  scoreItemValue: { fontSize: 14, color: EVA.ink, fontWeight: '800' },
  sectionTitle: { fontSize: 16, fontWeight: '800', color: EVA.ink, marginBottom: 16, letterSpacing: -0.2 },
  infoRow: { flexDirection: 'row', alignItems: 'flex-start', gap: 14, marginBottom: 20 },
  infoIconBox: { width: 36, height: 36, borderRadius: 18, backgroundColor: EVA.greenSoft, justifyContent: 'center', alignItems: 'center' },
  infoLabel: { fontSize: 12, color: EVA.muted, fontWeight: '600', marginBottom: 2 },
  infoText: { fontSize: 15, color: EVA.ink, fontWeight: '500' },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap' },
  noteText: { fontSize: 14, color: EVA.body, lineHeight: 22 },
  activityItem: { flexDirection: 'row', alignItems: 'center', gap: 14, padding: 20 },
  activityBorder: { borderBottomWidth: 1, borderBottomColor: EVA.hairline },
  activityIcon: { width: 36, height: 36, borderRadius: 18, backgroundColor: EVA.greenSoft, justifyContent: 'center', alignItems: 'center' },
  activityText: { fontSize: 14, color: EVA.ink, fontWeight: '600' },
  activityTime: { fontSize: 12, color: EVA.muted, marginTop: 4, fontWeight: '500' },
});
