import React, { useState } from 'react';
import {
  View, Text, StyleSheet, ScrollView, SafeAreaView,
  TouchableOpacity, TextInput, ActivityIndicator, Alert,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { Icon, AppBar, Button, Card } from '../components/ui';
import { ExtractedCard } from '../utils/ocr';
import { Lead } from '../types';
import OCRService from '../utils/ocr';
import DuplicateService, { DuplicateCheck } from '../utils/duplicate';
import StorageService from '../utils/storage';
import ScanQueueService from '../utils/scanQueue';

export default function FieldReviewScreen({ route, navigation }: any) {
  const { extracted, imageUri, queueMode = false, queueId } = route.params as {
    extracted: ExtractedCard;
    imageUri?: string;
    queueMode?: boolean;
    queueId?: string;
  };

  const [lead, setLead] = useState<Lead>(OCRService.createLeadFromExtraction(extracted));
  const [isSaving, setIsSaving] = useState(false);
  const [duplicateCheck, setDuplicateCheck] = useState<DuplicateCheck | null>(null);
  const [isChecking, setIsChecking] = useState(false);

  const isManualEntry = !extracted.rawText || extracted.rawText.trim().length === 0;

  React.useEffect(() => {
    checkForDuplicates();
  }, []);

  const checkForDuplicates = async () => {
    setIsChecking(true);
    try {
      const existingLeads = await StorageService.getLeads();
      setDuplicateCheck(DuplicateService.checkDuplicate(lead, existingLeads));
    } catch (error) {
      console.error(error);
    } finally {
      setIsChecking(false);
    }
  };

  const updateField = (field: keyof Lead, value: string) => {
    setLead(prev => ({ ...prev, [field]: value }));
  };

  const handleSave = async () => {
    if (duplicateCheck?.type === 'exact') {
      Alert.alert('Duplicate Found', `This card matches "${duplicateCheck.existing?.name}" already in your list.`, [
        { text: 'View Existing', onPress: () => navigation.navigate('LeadDetail', { lead: duplicateCheck.existing }) },
        { text: 'Back', style: 'cancel' },
      ]);
      return;
    }

    await handleCreateNew();
  };

  const finishQueueSave = () => {
    if (queueMode && queueId) {
      ScanQueueService.removeCard(queueId);
      navigation.goBack();
      return true;
    }

    return false;
  };

  const handleCreateNew = async () => {
    setIsSaving(true);
    try {
      await StorageService.saveLead(lead);

      if (finishQueueSave()) {
        return;
      }

      Alert.alert('Success', 'Lead saved successfully!', [
        { text: 'View', onPress: () => navigation.navigate('LeadDetail', { lead }) },
        { text: 'Done', onPress: () => navigation.reset({ index: 0, routes: [{ name: 'Main' }] }) },
      ]);
    } catch (error) {
      Alert.alert('Error', 'Failed to save lead');
    } finally {
      setIsSaving(false);
    }
  };

  const handleMerge = async () => {
    if (!duplicateCheck?.existing) return;
    setIsSaving(true);
    try {
      const merged = { ...lead, id: duplicateCheck.existing.id };
      await StorageService.mergeLead(duplicateCheck.existing.id, merged);

      if (finishQueueSave()) {
        return;
      }

      Alert.alert('Success', 'Lead updated successfully!', [
        { text: 'View', onPress: () => navigation.navigate('LeadDetail', { lead: merged }) },
        { text: 'Done', onPress: () => navigation.reset({ index: 0, routes: [{ name: 'Main' }] }) },
      ]);
    } catch (error) {
      Alert.alert('Error', 'Failed to merge lead');
    } finally {
      setIsSaving(false);
    }
  };

  const getConfidenceColor = (confidence: number) => {
    if (confidence >= 0.9) return EVA.greenDeep;
    if (confidence >= 0.8) return EVA.warn;
    return EVA.danger;
  };

  const renderField = (label: string, fieldKey: keyof Lead, confidence: number) => {
    const value = String(lead[fieldKey] || '');
    const isConfident = confidence >= 0.85;
    const showConfidence = confidence > 0;

    return (
      <View key={fieldKey} style={styles.fieldContainer}>
        <View style={styles.fieldHeader}>
          <Text style={styles.fieldLabel}>{label}</Text>
          {showConfidence && (
            <View style={[styles.confidenceBadge, { backgroundColor: getConfidenceColor(confidence) + '15' }]}>
              <Text style={[styles.confidenceText, { color: getConfidenceColor(confidence) }]}>
                {Math.round(confidence * 100)}% Match
              </Text>
            </View>
          )}
        </View>
        <View style={styles.inputWrapper}>
          <TextInput
            style={styles.input}
            value={value}
            onChangeText={text => updateField(fieldKey, text)}
            placeholder={`Enter ${label.toLowerCase()}`}
            placeholderTextColor={EVA.muted}
          />
          {showConfidence && !isConfident && (
            <Icon name="alert-circle" size={18} color={EVA.warn} />
          )}
        </View>
      </View>
    );
  };

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: EVA.canvas }}>
      <AppBar
        title="Review Data"
        sub="Verify extracted details"
        left={
          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.iconButton}>
            <Icon name="arrow-left" size={20} color={EVA.ink} />
          </TouchableOpacity>
        }
      />

      <ScrollView style={styles.container} showsVerticalScrollIndicator={false}>

        {/* Status Alerts */}
        <View style={styles.alertsContainer}>
          {isManualEntry && (
            <View style={[styles.alertBox, { backgroundColor: EVA.greenSoft, borderColor: EVA.green + '33' }]}>
              <Icon name="edit-2" size={20} color={EVA.greenDeep} />
              <Text style={[styles.alertText, { color: EVA.greenDeep }]}>Card captured! Fill in details below.</Text>
            </View>
          )}

          {extracted.cardQuality !== undefined && extracted.cardQuality > 0 && (
            <View style={[
              styles.alertBox,
              {
                backgroundColor: extracted.cardQuality >= 0.85 ? EVA.greenSoft : extracted.cardQuality >= 0.70 ? EVA.warnSoft : EVA.dangerSoft,
                borderColor: (extracted.cardQuality >= 0.85 ? EVA.green : extracted.cardQuality >= 0.70 ? EVA.warn : EVA.danger) + '33',
              }
            ]}>
              <Icon
                name={extracted.cardQuality >= 0.85 ? "check-circle" : extracted.cardQuality >= 0.70 ? "alert-circle" : "x-circle"}
                size={24}
                color={extracted.cardQuality >= 0.85 ? EVA.greenDeep : extracted.cardQuality >= 0.70 ? EVA.warn : EVA.danger}
              />
              <View style={{ flex: 1 }}>
                <Text style={[styles.alertTitle, { color: extracted.cardQuality >= 0.85 ? EVA.greenDeep : extracted.cardQuality >= 0.70 ? EVA.warn : EVA.danger }]}>
                  Quality Score: {Math.round(extracted.cardQuality * 100)}%
                </Text>
                <Text style={[styles.alertSub, { color: extracted.cardQuality >= 0.85 ? EVA.greenDeep : extracted.cardQuality >= 0.70 ? EVA.warn : EVA.danger }]}>
                  {extracted.cardQuality >= 0.85 ? 'Excellent extraction. Review and save.' : extracted.cardQuality >= 0.70 ? 'Fair extraction. Please double check fields.' : 'Poor extraction. Manual fixes likely needed.'}
                </Text>
              </View>
            </View>
          )}

          {isChecking && (
            <View style={styles.alertBox}>
              <ActivityIndicator size="small" color={EVA.greenDeep} />
              <Text style={styles.alertText}>Checking for duplicates...</Text>
            </View>
          )}

          {duplicateCheck && !isChecking && (
            <View style={[styles.alertBox, { backgroundColor: duplicateCheck.type === 'exact' ? EVA.dangerSoft : EVA.warnSoft, borderColor: (duplicateCheck.type === 'exact' ? EVA.danger : EVA.warn) + '33' }]}>
              <Icon name={duplicateCheck.type === 'exact' ? 'x-circle' : 'alert-circle'} size={20} color={duplicateCheck.type === 'exact' ? EVA.danger : EVA.warn} />
              <Text style={[styles.alertText, { color: duplicateCheck.type === 'exact' ? EVA.danger : EVA.warn }]}>
                {duplicateCheck.type === 'exact' ? 'Exact match found' : 'Possible duplicate'}: {duplicateCheck.existing?.name}
              </Text>
            </View>
          )}
        </View>

        {/* Editable Fields */}
        <Card style={{ padding: 24 }}>
          <Text style={styles.sectionTitle}>Contact Fields</Text>
          {renderField('Full Name', 'name', extracted.confidence.name)}
          {renderField('Job Title', 'role', extracted.confidence.role)}
          {renderField('Company', 'company', extracted.confidence.company)}
          {renderField('Email Address', 'email', extracted.confidence.email)}
          {renderField('Phone Number', 'phone', extracted.confidence.phone)}
          {renderField('Location', 'location', extracted.confidence.location)}

          <View style={styles.fieldContainer}>
            <Text style={styles.fieldLabel}>Notes (Optional)</Text>
            <View style={[styles.inputWrapper, { height: 'auto' }]}>
              <TextInput
                style={[styles.input, styles.noteInput]}
                value={lead.note}
                onChangeText={text => updateField('note', text)}
                placeholder="Add context or follow-up details..."
                placeholderTextColor={EVA.muted}
                multiline
              />
            </View>
          </View>
        </Card>

        {/* Save Button */}
        <View style={styles.actionContainer}>
          <Button
            title={isSaving ? 'Saving Lead...' : 'Save Lead'}
            onPress={handleSave}
            disabled={isSaving || isChecking}
            size="lg"
            full
          />
        </View>
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
  alertsContainer: { gap: 12, marginBottom: 20 },
  alertBox: { flexDirection: 'row', alignItems: 'center', backgroundColor: EVA.surface, borderWidth: 1, borderColor: EVA.hairline, padding: 16, borderRadius: 16, gap: 12 },
  alertTitle: { fontSize: 14, fontWeight: '800' },
  alertSub: { fontSize: 12, marginTop: 2, fontWeight: '500', opacity: 0.8 },
  alertText: { flex: 1, fontSize: 14, fontWeight: '600', color: EVA.ink },
  sectionTitle: { fontSize: 18, fontWeight: '800', color: EVA.ink, marginBottom: 20, letterSpacing: -0.2 },
  fieldContainer: { marginBottom: 20 },
  fieldHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 },
  fieldLabel: { fontSize: 13, fontWeight: '700', color: EVA.body },
  confidenceBadge: { paddingHorizontal: 8, paddingVertical: 4, borderRadius: 6 },
  confidenceText: { fontSize: 11, fontWeight: '800' },
  inputWrapper: { flexDirection: 'row', alignItems: 'center', backgroundColor: EVA.canvas, borderWidth: 1.5, borderColor: EVA.hairline, borderRadius: 12, paddingHorizontal: 16, height: 52 },
  input: { flex: 1, color: EVA.ink, fontSize: 15, fontWeight: '500' },
  noteInput: { height: 100, paddingTop: 16, paddingBottom: 16, textAlignVertical: 'top' },
  actionContainer: { marginTop: 8 },
});
