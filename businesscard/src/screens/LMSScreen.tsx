import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, SafeAreaView, FlatList,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { AppBar, Icon, Card } from '../components/ui';
import { TEAM } from '../utils/data';

export default function LMSScreen() {
  const [team] = useState(TEAM);

  const renderTeamMember = ({ item, index }: any) => (
    <Card style={styles.memberCard}>
      <View style={styles.memberRow}>
        <View style={styles.rankBadge}>
          <Text style={styles.rankText}>#{index + 1}</Text>
        </View>
        <View style={styles.memberInfo}>
          <Text style={styles.memberName}>{item.name}</Text>
          <Text style={styles.memberRole}>{item.role}</Text>
          <View style={styles.regionRow}>
            <Icon name="map-pin" size={12} color={EVA.muted} />
            <Text style={styles.memberRegion}>{item.region}</Text>
          </View>
        </View>
        <View style={styles.statsBox}>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>{item.captured}</Text>
            <Text style={styles.statLabel}>Total</Text>
          </View>
          <View style={styles.statDivider} />
          <View style={styles.statItem}>
            <Text style={styles.statValueToday}>+{item.todayDelta}</Text>
            <Text style={styles.statLabel}>Today</Text>
          </View>
        </View>
      </View>
    </Card>
  );

  const totalCaptured = team.reduce((sum, m) => sum + m.captured, 0);
  const totalToday = team.reduce((sum, m) => sum + m.todayDelta, 0);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <AppBar
        title="Leaderboard"
        dark={false}
        left={<Icon name="bar-chart-2" size={24} color={EVA.greenDeep} />}
      />

      <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>
        
        {/* Team Stats Summary */}
        <LinearGradient
          colors={EVA.greenGradient}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={[styles.summaryCard, EVA.shadow]}
        >
          <View style={styles.summaryItem}>
            <Text style={styles.summaryValueWhite}>{totalCaptured}</Text>
            <Text style={styles.summaryLabelWhite}>Team Total</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Text style={styles.summaryValueWhite}>{totalToday}</Text>
            <Text style={styles.summaryLabelWhite}>Added Today</Text>
          </View>
          <View style={styles.summaryDivider} />
          <View style={styles.summaryItem}>
            <Text style={styles.summaryValueWhite}>{team.length}</Text>
            <Text style={styles.summaryLabelWhite}>Members</Text>
          </View>
        </LinearGradient>

        <View style={styles.headerRow}>
          <Text style={styles.sectionTitle}>Top Performers</Text>
          <Icon name="award" size={20} color={EVA.warn} />
        </View>

        {/* Team Leaderboard */}
        <FlatList
          data={team}
          renderItem={renderTeamMember}
          keyExtractor={(item) => item.id}
          scrollEnabled={false}
          contentContainerStyle={styles.listContent}
        />
        
        <View style={{ height: 40 }} />
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20 },
  summaryCard: {
    flexDirection: 'row',
    borderRadius: 24,
    paddingVertical: 24,
    marginBottom: 32,
    alignItems: 'center',
  },
  summaryItem: { flex: 1, alignItems: 'center' },
  summaryValueWhite: { fontSize: 28, fontWeight: '800', color: '#fff', letterSpacing: -1 },
  summaryLabelWhite: { fontSize: 13, fontWeight: '600', color: 'rgba(255,255,255,0.8)', marginTop: 4 },
  summaryDivider: { width: 1, height: 40, backgroundColor: 'rgba(255,255,255,0.2)' },
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 16 },
  sectionTitle: { fontSize: 20, fontWeight: '800', color: EVA.ink, letterSpacing: -0.5 },
  listContent: { gap: 16 },
  memberCard: { padding: 16 },
  memberRow: { flexDirection: 'row', alignItems: 'center' },
  rankBadge: {
    width: 32, height: 32, borderRadius: 16, backgroundColor: EVA.canvas,
    justifyContent: 'center', alignItems: 'center', marginRight: 16,
    borderWidth: 1, borderColor: EVA.hairline,
  },
  rankText: { fontSize: 13, fontWeight: '800', color: EVA.muted },
  memberInfo: { flex: 1 },
  memberName: { fontSize: 16, fontWeight: '700', color: EVA.ink, letterSpacing: -0.2 },
  memberRole: { fontSize: 13, color: EVA.muted, fontWeight: '500', marginTop: 2 },
  regionRow: { flexDirection: 'row', alignItems: 'center', gap: 4, marginTop: 4 },
  memberRegion: { fontSize: 12, color: EVA.body, fontWeight: '500' },
  statsBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: EVA.canvas, borderRadius: 12, padding: 8, borderWidth: 1, borderColor: EVA.hairline },
  statItem: { alignItems: 'center', minWidth: 44 },
  statDivider: { width: 1, height: 24, backgroundColor: EVA.hairline, marginHorizontal: 8 },
  statValue: { fontSize: 16, fontWeight: '800', color: EVA.ink },
  statValueToday: { fontSize: 16, fontWeight: '800', color: EVA.greenDeep },
  statLabel: { fontSize: 10, fontWeight: '600', color: EVA.muted, marginTop: 2 },
});
