import React, { useState, useCallback } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  SafeAreaView,
  StatusBar,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { AppBar, Icon, Card, Chip } from '../components/ui';
import { Lead } from '../types';
import StorageService from '../utils/storage';

export default function HomeScreen({ navigation }: any) {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [syncStatus, setSyncStatus] = useState<'synced' | 'syncing'>('synced');

  useFocusEffect(
    useCallback(() => {
      StorageService.getLeads().then(setLeads).catch(console.error);
    }, []),
  );

  const newLeads = leads.filter((l) => l.status === 'new');
  const recentActivity = leads.flatMap((l) => l.activity.slice(0, 2)).slice(0, 5);

  const handleRefresh = () => {
    setSyncStatus('syncing');
    StorageService.getLeads()
      .then(setLeads)
      .catch(console.error)
      .finally(() => setSyncStatus('synced'));
  };

  const handleLeadPress = (leadId: string) => {
    navigation.navigate('LeadDetail', { leadId });
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <StatusBar barStyle="dark-content" backgroundColor={EVA.canvas} />
      <AppBar
        title="Dashboard"
        dark={false}
        left={<Icon name="home" size={24} color={EVA.greenDeep} />}
        right={
          <TouchableOpacity onPress={handleRefresh} style={styles.iconButton}>
            <Icon
              name="refresh"
              size={20}
              color={syncStatus === 'syncing' ? EVA.green : EVA.muted}
            />
          </TouchableOpacity>
        }
      />
      <ScrollView style={{ flex: 1 }} showsVerticalScrollIndicator={false}>
        <View style={styles.container}>
          {/* Summary Stats */}
          <View style={styles.statsGrid}>
            <LinearGradient
              colors={EVA.greenGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={[styles.statCardPrimary, EVA.shadow]}
            >
              <Text style={styles.statNumberPrimary}>{leads.length}</Text>
              <Text style={styles.statLabelPrimary}>Total Leads</Text>
            </LinearGradient>

            <View style={[styles.statCardSecondary, EVA.shadow]}>
              <Text style={styles.statNumberSecondary}>{newLeads.length}</Text>
              <Text style={styles.statLabelSecondary}>New Today</Text>
            </View>
          </View>

          {/* New Leads Section */}
          {newLeads.length > 0 && (
            <View style={styles.section}>
              <View style={styles.sectionHeader}>
                <Text style={styles.sectionTitle}>New Leads</Text>
                <TouchableOpacity onPress={() => navigation.navigate('Leads')}>
                  <Text style={styles.sectionLink}>View All</Text>
                </TouchableOpacity>
              </View>
              
              <View style={{ gap: 12 }}>
                {newLeads.map((lead) => (
                  <Card key={lead.id} onPress={() => handleLeadPress(lead.id)}>
                    <View style={styles.leadHeader}>
                      <View style={{ flex: 1, paddingRight: 12 }}>
                        <Text style={styles.leadName} numberOfLines={1}>{lead.name}</Text>
                        <Text style={styles.leadRole} numberOfLines={1}>{lead.role}</Text>
                      </View>
                      <View
                        style={[
                          styles.scoreCircle,
                          {
                            borderColor:
                              lead.score >= 80
                                ? EVA.green
                                : lead.score >= 50
                                ? EVA.warn
                                : EVA.danger,
                          },
                        ]}
                      >
                        <Text
                          style={[
                            styles.scoreText,
                            {
                              color:
                                lead.score >= 80
                                  ? EVA.greenDeep
                                  : lead.score >= 50
                                  ? EVA.warn
                                  : EVA.danger,
                            },
                          ]}
                        >
                          {lead.score}
                        </Text>
                      </View>
                    </View>
                    <View style={styles.companyRow}>
                      <Icon name="building" size={14} color={EVA.muted} />
                      <Text style={styles.leadCompany} numberOfLines={1}>{lead.company}</Text>
                    </View>
                    <View style={styles.tagsRow}>
                      {lead.tags.slice(0, 3).map((tag) => (
                        <Chip key={tag} label={tag} />
                      ))}
                    </View>
                  </Card>
                ))}
              </View>
            </View>
          )}

          {/* Recent Activity */}
          {recentActivity.length > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Recent Activity</Text>
              <Card style={{ padding: 0, overflow: 'hidden' }}>
                {recentActivity.map((activity, idx) => (
                  <View
                    key={idx}
                    style={[
                      styles.activityItem,
                      idx !== recentActivity.length - 1 && styles.activityItemBorder,
                    ]}
                  >
                    <View style={styles.activityIcon}>
                      <Icon
                        name={activity.k === 'scan' ? 'camera' : activity.k === 'email' ? 'mail' : 'check'}
                        size={16}
                        color={EVA.greenDeep}
                      />
                    </View>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.activityText}>{activity.text}</Text>
                      <Text style={styles.activityTime}>{activity.t}</Text>
                    </View>
                  </View>
                ))}
              </Card>
            </View>
          )}
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 20,
    gap: 32,
    paddingBottom: 40,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: EVA.surface,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 2,
  },
  statsGrid: {
    flexDirection: 'row',
    gap: 16,
  },
  statCardPrimary: {
    flex: 1,
    borderRadius: 24,
    padding: 24,
    justifyContent: 'center',
  },
  statCardSecondary: {
    flex: 1,
    backgroundColor: EVA.surface,
    borderRadius: 24,
    padding: 24,
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: 'rgba(0,0,0,0.03)',
  },
  statNumberPrimary: {
    fontSize: 36,
    fontWeight: '800',
    color: '#FFFFFF',
    letterSpacing: -1,
  },
  statLabelPrimary: {
    fontSize: 14,
    color: 'rgba(255,255,255,0.9)',
    fontWeight: '600',
    marginTop: 4,
  },
  statNumberSecondary: {
    fontSize: 36,
    fontWeight: '800',
    color: EVA.ink,
    letterSpacing: -1,
  },
  statLabelSecondary: {
    fontSize: 14,
    color: EVA.muted,
    fontWeight: '600',
    marginTop: 4,
  },
  section: {
    gap: 16,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'baseline',
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: '800',
    color: EVA.ink,
    letterSpacing: -0.5,
  },
  sectionLink: {
    fontSize: 14,
    fontWeight: '600',
    color: EVA.greenDeep,
  },
  leadHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  leadName: {
    fontSize: 17,
    fontWeight: '700',
    color: EVA.ink,
    letterSpacing: -0.2,
  },
  leadRole: {
    fontSize: 14,
    color: EVA.muted,
    fontWeight: '500',
    marginTop: 2,
  },
  companyRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    marginBottom: 16,
  },
  leadCompany: {
    fontSize: 14,
    color: EVA.body,
    fontWeight: '500',
    flex: 1,
  },
  scoreCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    borderWidth: 3,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: EVA.surface,
  },
  scoreText: {
    fontSize: 15,
    fontWeight: '800',
  },
  tagsRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  activityItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    padding: 20,
  },
  activityItemBorder: {
    borderBottomWidth: 1,
    borderBottomColor: EVA.hairline,
  },
  activityIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    backgroundColor: EVA.greenSoft,
    justifyContent: 'center',
    alignItems: 'center',
  },
  activityText: {
    fontSize: 15,
    color: EVA.ink,
    fontWeight: '600',
  },
  activityTime: {
    fontSize: 13,
    color: EVA.muted,
    marginTop: 4,
    fontWeight: '500',
  },
});
