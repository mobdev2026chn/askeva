import React, { useState, useCallback } from 'react';
import {
  View, Text, StyleSheet, ScrollView, TouchableOpacity,
  SafeAreaView, TextInput, FlatList, StatusBar,
} from 'react-native';
import { useFocusEffect } from '@react-navigation/native';
import { EVA } from '../utils/theme';
import { AppBar, Icon, Card, Chip } from '../components/ui';
import { Lead } from '../types';
import StorageService from '../utils/storage';

const FILTERS = [
  { key: null, label: 'All' },
  { key: 'new', label: 'New' },
  { key: 'contacted', label: 'Contacted' },
  { key: 'followup', label: 'Follow-up' },
];

function ScoreBadge({ score }: { score: number }) {
  const color = score >= 80 ? EVA.greenDeep : score >= 50 ? EVA.warn : EVA.danger;
  const bg = score >= 80 ? EVA.greenSoft : score >= 50 ? EVA.warnSoft : EVA.dangerSoft;
  return (
    <View style={[styles.scoreBadge, { backgroundColor: bg, borderColor: color + '33' }]}>
      <Text style={[styles.scoreBadgeText, { color }]}>{score}</Text>
    </View>
  );
}

export default function LeadListScreen({ navigation }: any) {
  const [leads, setLeads] = useState<Lead[]>([]);
  const [searchText, setSearchText] = useState('');
  const [filterStatus, setFilterStatus] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useFocusEffect(
    useCallback(() => {
      const load = async () => {
        try {
          setIsLoading(true);
          setLeads(await StorageService.getLeads());
        } catch (e) {
          console.error(e);
        } finally {
          setIsLoading(false);
        }
      };
      load();
    }, []),
  );

  const filtered = leads.filter((l) => {
    const q = searchText.toLowerCase();
    return (
      (l.name.toLowerCase().includes(q) || l.company.toLowerCase().includes(q)) &&
      (!filterStatus || l.status === filterStatus)
    );
  });

  const renderLead = ({ item }: { item: Lead }) => (
    <Card onPress={() => navigation.navigate('LeadDetail', { leadId: item.id })}>
      <View style={styles.leadHeader}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{(item.name?.[0] || '?').toUpperCase()}</Text>
        </View>
        <View style={{ flex: 1, marginLeft: 14 }}>
          <Text style={styles.leadName} numberOfLines={1}>{item.name}</Text>
          <Text style={styles.leadRole} numberOfLines={1}>{item.role}</Text>
          <View style={styles.companyRow}>
            <Icon name="building" size={13} color={EVA.muted} />
            <Text style={styles.leadCompany} numberOfLines={1}>{item.company}</Text>
          </View>
        </View>
        <ScoreBadge score={item.score} />
      </View>
      <View style={styles.leadFooter}>
        <Text style={styles.leadMeta}>{item.capturedAt}</Text>
        {item.tags.slice(0, 2).map(t => <Chip key={t} label={t} />)}
      </View>
    </Card>
  );

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <StatusBar barStyle="dark-content" backgroundColor={EVA.canvas} />
      <AppBar
        title="Leads"
        dark={false}
        left={<Icon name="users" size={24} color={EVA.greenDeep} />}
        right={
          <View style={styles.headerCount}>
            <Text style={styles.headerCountText}>{filtered.length}</Text>
          </View>
        }
      />

      <View style={styles.searchContainer}>
        <View style={styles.searchBox}>
          <Icon name="search" size={18} color={EVA.muted} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search name or company…"
            placeholderTextColor={EVA.muted}
            value={searchText}
            onChangeText={setSearchText}
          />
          {searchText.length > 0 && (
            <TouchableOpacity onPress={() => setSearchText('')}>
              <Icon name="close" size={16} color={EVA.muted} />
            </TouchableOpacity>
          )}
        </View>
      </View>

      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        style={styles.filterScroll}
        contentContainerStyle={styles.filterContent}
      >
        {FILTERS.map((f) => {
          const active = filterStatus === f.key;
          return (
            <TouchableOpacity
              key={String(f.key)}
              onPress={() => setFilterStatus(f.key)}
              activeOpacity={0.7}
              style={[styles.filterTab, active && styles.filterTabActive]}
            >
              <Text style={[styles.filterTabText, active && styles.filterTabTextActive]}>
                {f.label}
              </Text>
            </TouchableOpacity>
          );
        })}
      </ScrollView>

      <FlatList
        data={filtered}
        renderItem={renderLead}
        keyExtractor={(i) => i.id}
        contentContainerStyle={styles.listContent}
        scrollEnabled
        showsVerticalScrollIndicator={false}
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <View style={styles.emptyIcon}>
              <Icon name="users" size={32} color={EVA.muted} />
            </View>
            <Text style={styles.emptyTitle}>{isLoading ? 'Loading…' : 'No leads found'}</Text>
            <Text style={styles.emptySubtitle}>
              {isLoading ? '' : 'Scan a business card to add your first lead.'}
            </Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  searchContainer: { paddingHorizontal: 20, paddingTop: 16, paddingBottom: 8 },
  searchBox: {
    flexDirection: 'row', alignItems: 'center', backgroundColor: EVA.surface,
    borderRadius: 16, paddingHorizontal: 16, gap: 10, borderWidth: 1, borderColor: EVA.hairline,
    shadowColor: '#000', shadowOffset: { width: 0, height: 2 }, shadowOpacity: 0.04, shadowRadius: 8, elevation: 1,
  },
  searchInput: { flex: 1, paddingVertical: 14, color: EVA.ink, fontSize: 15, fontWeight: '500' },
  filterScroll: { maxHeight: 52 },
  filterContent: { flexDirection: 'row', gap: 8, paddingHorizontal: 20, paddingVertical: 8 },
  filterTab: {
    paddingVertical: 8, paddingHorizontal: 18, borderRadius: 20,
    backgroundColor: EVA.surface, borderWidth: 1, borderColor: EVA.hairline,
  },
  filterTabActive: { backgroundColor: EVA.greenDeep, borderColor: EVA.greenDeep },
  filterTabText: { fontSize: 14, fontWeight: '600', color: EVA.muted },
  filterTabTextActive: { color: '#fff' },
  listContent: { padding: 20, gap: 4, paddingBottom: 40 },
  leadHeader: { flexDirection: 'row', alignItems: 'center' },
  avatar: {
    width: 48, height: 48, borderRadius: 24,
    backgroundColor: EVA.greenSoft, justifyContent: 'center', alignItems: 'center',
  },
  avatarText: { fontSize: 20, fontWeight: '800', color: EVA.greenDeep },
  leadName: { fontSize: 16, fontWeight: '700', color: EVA.ink, letterSpacing: -0.2 },
  leadRole: { fontSize: 13, color: EVA.muted, fontWeight: '500', marginTop: 2 },
  companyRow: { flexDirection: 'row', alignItems: 'center', gap: 5, marginTop: 4 },
  leadCompany: { fontSize: 13, color: EVA.body, fontWeight: '500', flex: 1 },
  scoreBadge: {
    minWidth: 44, paddingHorizontal: 10, paddingVertical: 6, borderRadius: 12,
    alignItems: 'center', borderWidth: 1,
  },
  scoreBadgeText: { fontSize: 15, fontWeight: '800' },
  leadFooter: { flexDirection: 'row', alignItems: 'center', marginTop: 14, gap: 8 },
  leadMeta: { fontSize: 12, color: EVA.muted, fontWeight: '500', flex: 1 },
  emptyState: { flex: 1, alignItems: 'center', paddingVertical: 60, gap: 12 },
  emptyIcon: {
    width: 72, height: 72, borderRadius: 36, backgroundColor: EVA.canvas,
    justifyContent: 'center', alignItems: 'center', marginBottom: 4,
  },
  emptyTitle: { fontSize: 18, fontWeight: '700', color: EVA.ink },
  emptySubtitle: { fontSize: 14, color: EVA.muted, textAlign: 'center', paddingHorizontal: 32 },
  headerCount: {
    backgroundColor: EVA.greenSoft, borderRadius: 10, paddingHorizontal: 10, paddingVertical: 4,
  },
  headerCountText: { fontSize: 13, fontWeight: '800', color: EVA.greenDeep },
});
