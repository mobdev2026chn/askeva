import React, { useCallback, useState } from 'react';
import { SafeAreaView, ScrollView, View, Text, StyleSheet } from 'react-native';
import { useFocusEffect } from '@react-navigation/native';

import { AppBar, Button, Card, Icon } from '../components/ui';
import { EVA } from '../utils/theme';
import ScanQueueService, { QueuedCard } from '../utils/scanQueue';

export default function BatchQueueScreen({ navigation }: any) {
  const [cards, setCards] = useState<QueuedCard[]>([]);

  const loadQueue = useCallback(() => {
    setCards(ScanQueueService.getCards());
  }, []);

  useFocusEffect(
    useCallback(() => {
      loadQueue();
    }, [loadQueue]),
  );

  const handleReviewCard = (card: QueuedCard) => {
    navigation.navigate('FieldReview', {
      extracted: card.extracted,
      imageUri: card.imageUri,
      queueMode: true,
      queueId: card.id,
    });
  };

  const handleClearQueue = () => {
    ScanQueueService.clear();
    loadQueue();
  };

  const handleScanMore = () => {
    navigation.goBack();
  };

  return (
    <SafeAreaView style={styles.safeArea}>
      <AppBar
        title="Batch Queue"
        sub={cards.length === 0 ? 'No cards waiting to save' : `${cards.length} card${cards.length === 1 ? '' : 's'} waiting`}
        left={
          <Button
            title="Back"
            kind="ghost"
            size="sm"
            onPress={handleScanMore}
          />
        }
      />

      <ScrollView style={styles.container} contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.headerRow}>
          <View>
            <Text style={styles.title}>Save cards individually</Text>
            <Text style={styles.subtitle}>Review each queued card, edit if needed, and save it one at a time.</Text>
          </View>
          <View style={styles.badge}>
            <Text style={styles.badgeText}>{cards.length}</Text>
          </View>
        </View>

        {cards.length === 0 ? (
          <Card style={styles.emptyCard}>
            <View style={styles.emptyIconWrap}>
              <Icon name="check-circle" size={28} color={EVA.greenDeep} />
            </View>
            <Text style={styles.emptyTitle}>Queue is clear</Text>
            <Text style={styles.emptyBody}>Capture another card to add it to the batch queue.</Text>
            <Button title="Scan Again" onPress={handleScanMore} full style={{ marginTop: 18 }} />
          </Card>
        ) : (
          cards.map((card, index) => (
            <Card key={card.id} style={styles.cardItem}>
              <View style={styles.cardHeader}>
                <View style={styles.cardNumberBadge}>
                  <Text style={styles.cardNumberText}>{index + 1}</Text>
                </View>
                <View style={{ flex: 1, marginLeft: 12 }}>
                  <Text style={styles.cardName}>{card.lead.name || 'Unnamed Card'}</Text>
                  <Text style={styles.cardMeta}>{card.lead.company || 'Unknown company'} • {card.lead.email || 'No email'}</Text>
                </View>
                <Icon name="chevR" size={20} color={EVA.muted} />
              </View>

              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Phone</Text>
                <Text style={styles.metaValue}>{card.lead.phone || '—'}</Text>
              </View>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Location</Text>
                <Text style={styles.metaValue}>{card.lead.location || '—'}</Text>
              </View>
              <View style={styles.metaRow}>
                <Text style={styles.metaLabel}>Captured</Text>
                <Text style={styles.metaValue}>{new Date(card.createdAt).toLocaleString()}</Text>
              </View>

              <Button title="Review and Save" onPress={() => handleReviewCard(card)} full style={{ marginTop: 18 }} />
            </Card>
          ))
        )}

        {cards.length > 0 && (
          <View style={styles.footerActions}>
            <Button title="Scan More" kind="secondary" onPress={handleScanMore} full style={{ marginBottom: 12 }} />
            <Button title="Clear Queue" kind="ghost" onPress={handleClearQueue} full />
          </View>
        )}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: EVA.canvas,
  },
  container: {
    flex: 1,
  },
  content: {
    padding: 20,
    paddingBottom: 40,
  },
  headerRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
    gap: 16,
  },
  title: {
    fontSize: 22,
    fontWeight: '800',
    color: EVA.ink,
    letterSpacing: -0.4,
  },
  subtitle: {
    fontSize: 14,
    color: EVA.muted,
    marginTop: 6,
    lineHeight: 20,
  },
  badge: {
    minWidth: 42,
    height: 42,
    borderRadius: 21,
    backgroundColor: EVA.green,
    justifyContent: 'center',
    alignItems: 'center',
  },
  badgeText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '800',
  },
  emptyCard: {
    alignItems: 'center',
  },
  emptyIconWrap: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: EVA.greenSoft,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  emptyTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: EVA.ink,
  },
  emptyBody: {
    fontSize: 14,
    color: EVA.muted,
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 20,
  },
  cardItem: {
    marginBottom: 16,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  cardNumberBadge: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: EVA.greenSoft,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardNumberText: {
    color: EVA.greenDeep,
    fontWeight: '800',
  },
  cardName: {
    fontSize: 17,
    fontWeight: '800',
    color: EVA.ink,
  },
  cardMeta: {
    fontSize: 13,
    color: EVA.muted,
    marginTop: 4,
  },
  metaRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 12,
  },
  metaLabel: {
    fontSize: 13,
    fontWeight: '700',
    color: EVA.body,
  },
  metaValue: {
    fontSize: 13,
    color: EVA.ink,
    flexShrink: 1,
    textAlign: 'right',
  },
  footerActions: {
    marginTop: 12,
  },
});
