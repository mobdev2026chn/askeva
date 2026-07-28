import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { StatusBar } from 'expo-status-bar';

import LoginScreen from './screens/LoginScreen';
import HomeScreen from './screens/HomeScreen';
import LeadListScreen from './screens/LeadListScreen';
import ScanScreen from './screens/ScanScreen';
import LeadDetailScreen from './screens/LeadDetailScreen';
import MyCardScreen from './screens/MyCardScreen';
import LMSScreen from './screens/LMSScreen';
import FieldReviewScreen from './screens/FieldReviewScreen';
import BatchQueueScreen from './screens/BatchQueueScreen';

import { Icon } from './components/ui';
import { EVA } from './utils/theme';
import StorageService from './utils/storage';

const Stack = createNativeStackNavigator();
const Tab = createBottomTabNavigator();

// Tab navigator for authenticated screens
function TabNavigator() {
  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarActiveTintColor: EVA.green,
        tabBarInactiveTintColor: EVA.muted,
        tabBarStyle: {
          borderTopWidth: 1,
          borderTopColor: EVA.hairline,
          backgroundColor: EVA.surface,
          paddingBottom: 8,
          paddingTop: 8,
        },
        tabBarIcon: ({ color, size }) => {
          const icons: { [key: string]: string } = {
            Home: 'home',
            Leads: 'users',
            Scan: 'scan',
            LMS: 'chart',
            'My Card': 'target',
          };
          return <Icon name={icons[route.name] || 'home'} size={size} color={color} />;
        },
      })}
    >
      <Tab.Screen
        name="Home"
        component={HomeScreen}
        options={{ title: 'Home', tabBarLabel: 'Home' }}
      />
      <Tab.Screen
        name="Leads"
        component={LeadListScreen}
        options={{ title: 'Leads', tabBarLabel: 'Leads' }}
      />
      <Tab.Screen
        name="Scan"
        component={ScanScreen}
        options={{
          title: 'Scan Card',
          tabBarLabel: '',
          tabBarStyle: { display: 'none' },
        }}
      />
      <Tab.Screen
        name="LMS"
        component={LMSScreen}
        options={{ title: 'LMS', tabBarLabel: 'LMS' }}
      />
      <Tab.Screen
        name="MyCard"
        component={MyCardScreen}
        options={{ title: 'My Card', tabBarLabel: 'My Card' }}
      />
    </Tab.Navigator>
  );
}

export default function App() {
  useEffect(() => {
    // Initialize storage on app start
    StorageService.initialize();
  }, []);

  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
        }}
      >
        <Stack.Screen name="Login" component={LoginScreen} />
        <Stack.Screen name="Main" component={TabNavigator} />
        <Stack.Group
          screenOptions={{
            presentation: 'card',
          }}
        >
          <Stack.Screen name="LeadDetail" component={LeadDetailScreen} />
          <Stack.Screen name="FieldReview" component={FieldReviewScreen} />
          <Stack.Screen name="BatchQueue" component={BatchQueueScreen} />
        </Stack.Group>
      </Stack.Navigator>
      <StatusBar style="light" />
    </NavigationContainer>
  );
}
