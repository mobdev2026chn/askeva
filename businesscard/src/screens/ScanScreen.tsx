import React, { useEffect, useRef, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  SafeAreaView,
  Alert,
  ActivityIndicator,
  Animated,
} from 'react-native';
import { CameraView, CameraType, useCameraPermissions } from 'expo-camera';
import { LinearGradient } from 'expo-linear-gradient';
import { EVA } from '../utils/theme';
import { Icon } from '../components/ui';
import OCRService from '../utils/ocr';
import ScanQueueService from '../utils/scanQueue';

export default function ScanScreen({ navigation }: any) {
  const [permission, requestPermission] = useCameraPermissions();
  const [facing, setFacing] = useState<CameraType>('back');
  const [isTakingPhoto, setIsTakingPhoto] = useState(false);
  const [isProcessing, setIsProcessing] = useState(false);
  const [statusText, setStatusText] = useState('Position the card inside the frame');
  const [queuedCount, setQueuedCount] = useState(0);

  const cameraRef = useRef<CameraView | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;
  const isMountedRef = useRef(true);
  const captureLockRef = useRef(false);

  useEffect(() => {
    isMountedRef.current = true;
    setQueuedCount(ScanQueueService.count());

    if (permission && !permission.granted && permission.canAskAgain) {
      requestPermission();
    }

    const pulse = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.08,
          duration: 700,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 700,
          useNativeDriver: true,
        }),
      ]),
    );

    pulse.start();

    const unsubscribe = navigation.addListener('focus', () => {
      setQueuedCount(ScanQueueService.count());
    });

    return () => {
      unsubscribe();
      pulse.stop();
      isMountedRef.current = false;
      captureLockRef.current = false;
    };
  }, [navigation, permission, pulseAnim, requestPermission]);

  const openManualReview = (extracted: any, imageUri?: string) => {
    navigation.navigate('FieldReview', {
      extracted,
      imageUri,
    });
  };

  const queueCard = (extracted: any, imageUri?: string) => {
    const queuedCard = ScanQueueService.addCard(extracted, imageUri);
    setQueuedCount(ScanQueueService.count());
    setStatusText(`${queuedCard.lead.name || 'Card'} queued. ${ScanQueueService.count()} total waiting.`);
  };

  const takePicture = async () => {
    if (!cameraRef.current || captureLockRef.current || isTakingPhoto || isProcessing) {
      return;
    }

    let photoUri: string | undefined;

    try {
      captureLockRef.current = true;
      setIsTakingPhoto(true);
      setStatusText('Capturing card...');

      const photo = await cameraRef.current.takePictureAsync({
        base64: true,
        quality: 0.75,
        skipProcessing: false,
      });

      photoUri = photo?.uri;

      if (!photo?.base64) {
        Alert.alert('Error', 'Could not read image data from the camera.');
        return;
      }

      if (!isMountedRef.current) {
        return;
      }

      setIsTakingPhoto(false);
      setIsProcessing(true);
      setStatusText('Reading card details...');

      const extracted = await OCRService.extractCard(photo.base64);

      if (!isMountedRef.current) {
        return;
      }

      const hasAnyData = Boolean(
        extracted.name ||
          extracted.email ||
          extracted.phone ||
          extracted.company ||
          extracted.role ||
          extracted.location,
      );

      const hasRawText = Boolean(extracted.rawText && extracted.rawText.trim().length > 0);

      if (hasAnyData || hasRawText) {
        queueCard(extracted, photoUri);
        return;
      }

      Alert.alert(
        'Could not read text',
        'The image was captured, but OCR did not return readable text. Try again with the card closer, flatter, and without glare.',
        [
          {
            text: 'Try Again',
            style: 'default',
            onPress: () => setStatusText('Position the card inside the frame'),
          },
          {
            text: 'Fill Manually',
            onPress: () => openManualReview(extracted, photoUri),
          },
        ],
      );
    } catch (error) {
      console.error('Scan failed:', error);
      Alert.alert('Error', 'Failed to process card. Please try again.');
    } finally {
      if (isMountedRef.current) {
        setIsTakingPhoto(false);
        setIsProcessing(false);
        if (!navigation?.isFocused || navigation.isFocused()) {
          setStatusText('Position the card inside the frame');
        }
      }
      captureLockRef.current = false;
    }
  };

  if (!permission?.granted) {
    return (
      <SafeAreaView style={styles.permissionScreen}>
        <View style={styles.permissionContainer}>
          <LinearGradient
            colors={EVA.greenGradient}
            start={{ x: 0, y: 0 }}
            end={{ x: 1, y: 1 }}
            style={styles.permissionIcon}
          >
            <Icon name="camera" size={40} color="#fff" />
          </LinearGradient>

          <Text style={styles.permissionTitle}>Camera Access Needed</Text>

          <Text style={styles.permissionDescription}>
            Allow camera access to scan business cards.
          </Text>

          <TouchableOpacity
            style={styles.permissionButton}
            onPress={requestPermission}
            activeOpacity={0.85}
          >
            <LinearGradient
              colors={EVA.greenGradient}
              start={{ x: 0, y: 0 }}
              end={{ x: 1, y: 1 }}
              style={styles.permissionButtonGradient}
            >
              <Text style={styles.permissionButtonText}>Grant Permission</Text>
            </LinearGradient>
          </TouchableOpacity>

          <TouchableOpacity onPress={() => navigation.goBack()} style={styles.backLink}>
            <Text style={styles.backLinkText}>Go Back</Text>
          </TouchableOpacity>
        </View>
      </SafeAreaView>
    );
  }

  const busy = isTakingPhoto || isProcessing;

  return (
    <SafeAreaView style={styles.container}>
      <CameraView
        ref={cameraRef}
        facing={facing}
        style={StyleSheet.absoluteFill}
        autofocus="on"
      />

      <View pointerEvents="none" style={styles.overlay}>
        <View style={styles.maskTop} />

        <View style={styles.frameRow}>
          <View style={styles.maskSide} />

          <View style={styles.cardFrame}>
            <View style={[styles.corner, styles.topLeft]} />
            <View style={[styles.corner, styles.topRight]} />
            <View style={[styles.corner, styles.bottomLeft]} />
            <View style={[styles.corner, styles.bottomRight]} />

            {busy && (
              <View style={styles.processingOverlay}>
                <ActivityIndicator size="large" color={EVA.green} />
                <Text style={styles.processingText}>
                  {isTakingPhoto ? 'Capturing…' : 'Reading card…'}
                </Text>
              </View>
            )}
          </View>

          <View style={styles.maskSide} />
        </View>

        <View style={styles.maskBottom} />
      </View>

      <View style={styles.bottomPanel}>
        <Text style={styles.hint}>{busy ? statusText : 'Position the business card inside the frame'}</Text>
        <Text style={styles.subHint}>Keep the card flat, fill most of the frame, and avoid glare.</Text>

        <TouchableOpacity
          style={[styles.queueCta, queuedCount === 0 && styles.queueCtaDisabled]}
          onPress={() => navigation.navigate('BatchQueue')}
          disabled={queuedCount === 0}
        >
          <Text style={styles.queueCtaText}>{queuedCount > 0 ? `Review queue (${queuedCount})` : 'Queue is empty'}</Text>
        </TouchableOpacity>

        <View style={styles.controls}>
          <TouchableOpacity
            style={[styles.secondaryBtn, busy && styles.disabledBtn]}
            onPress={() => setFacing(f => (f === 'back' ? 'front' : 'back'))}
            disabled={busy}
          >
            <Icon name="refresh" size={22} color="#fff" />
          </TouchableOpacity>

          <Animated.View style={{ transform: [{ scale: pulseAnim }] }}>
            <TouchableOpacity
              style={[styles.captureRing, busy && styles.disabledBtn]}
              onPress={takePicture}
              disabled={busy}
              activeOpacity={0.85}
            >
              <LinearGradient
                colors={EVA.greenGradient}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 1 }}
                style={styles.captureButton}
              >
                {busy ? (
                  <ActivityIndicator color="#fff" size="small" />
                ) : (
                  <Icon name="camera" size={28} color="#fff" />
                )}
              </LinearGradient>
            </TouchableOpacity>
          </Animated.View>

          <TouchableOpacity
            style={[styles.secondaryBtn, busy && styles.disabledBtn]}
            onPress={() => navigation.goBack()}
            disabled={busy}
          >
            <Icon name="close" size={22} color="#fff" />
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
}

const FRAME_W = 320;
const FRAME_H = 205;
const CORNER = 30;

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  overlay: { ...StyleSheet.absoluteFillObject },
  maskTop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.65)' },
  frameRow: { flexDirection: 'row', height: FRAME_H },
  maskSide: { flex: 1, backgroundColor: 'rgba(0,0,0,0.65)' },
  maskBottom: { flex: 1.4, backgroundColor: 'rgba(0,0,0,0.65)' },
  cardFrame: {
    width: FRAME_W,
    height: FRAME_H,
    position: 'relative',
    borderRadius: 18,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.45)',
    backgroundColor: 'rgba(255,255,255,0.03)',
    overflow: 'hidden',
  },
  corner: {
    position: 'absolute',
    width: CORNER,
    height: CORNER,
    borderColor: EVA.green,
    borderWidth: 4,
    borderRadius: 4,
  },
  topLeft: { top: 0, left: 0, borderRightWidth: 0, borderBottomWidth: 0, borderTopLeftRadius: 18 },
  topRight: { top: 0, right: 0, borderLeftWidth: 0, borderBottomWidth: 0, borderTopRightRadius: 18 },
  bottomLeft: { bottom: 0, left: 0, borderRightWidth: 0, borderTopWidth: 0, borderBottomLeftRadius: 18 },
  bottomRight: { bottom: 0, right: 0, borderLeftWidth: 0, borderTopWidth: 0, borderBottomRightRadius: 18 },
  processingOverlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.55)',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 12,
  },
  processingText: { color: '#fff', fontSize: 14, fontWeight: '700' },
  bottomPanel: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    alignItems: 'center',
    paddingTop: 26,
    paddingBottom: 34,
    paddingHorizontal: 24,
    gap: 12,
  },
  hint: {
    color: 'rgba(255,255,255,0.88)',
    fontSize: 15,
    fontWeight: '800',
    textAlign: 'center',
  },
  subHint: {
    color: 'rgba(255,255,255,0.58)',
    fontSize: 12,
    fontWeight: '600',
    textAlign: 'center',
    marginBottom: 18,
  },
  queueCta: {
    paddingHorizontal: 18,
    paddingVertical: 10,
    borderRadius: 999,
    backgroundColor: 'rgba(255,255,255,0.14)',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.16)',
  },
  queueCtaDisabled: {
    opacity: 0.45,
  },
  queueCtaText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '700',
  },
  controls: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 40,
  },
  secondaryBtn: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: 'rgba(255,255,255,0.15)',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  captureRing: {
    width: 82,
    height: 82,
    borderRadius: 41,
    borderWidth: 3,
    borderColor: 'rgba(255,255,255,0.55)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  captureButton: {
    width: 68,
    height: 68,
    borderRadius: 34,
    justifyContent: 'center',
    alignItems: 'center',
  },
  disabledBtn: { opacity: 0.55 },
  permissionScreen: { flex: 1, backgroundColor: EVA.canvas },
  permissionContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 20,
    padding: 32,
  },
  permissionIcon: {
    width: 100,
    height: 100,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 8,
  },
  permissionTitle: { fontSize: 28, fontWeight: '800', color: EVA.ink, textAlign: 'center' },
  permissionDescription: { fontSize: 15, color: EVA.muted, textAlign: 'center', lineHeight: 22 },
  permissionButton: { width: '100%', maxWidth: 280, borderRadius: 18, overflow: 'hidden' },
  permissionButtonGradient: { paddingVertical: 16, paddingHorizontal: 24, alignItems: 'center' },
  permissionButtonText: { color: '#fff', fontWeight: '800', fontSize: 16 },
  backLink: { marginTop: 8 },
  backLinkText: { color: EVA.green, fontWeight: '700', fontSize: 14 },
});
