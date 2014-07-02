#include <Atm128Uart.h>
#include "udp_config.h"
#include "debug.h"
configuration JabberClientAppC
{
}
#define MAX_KEYBOARD_BUFFER 20
implementation
{
  components StdoDebugC;
  components MainC, JabberClientC;
  components LedsC;
  components BufferedLcdC, HplKS0108C, TouchScreenC;
  components Atm1280SpiC;
  components KeyboardC, HplPS2C;
  components HplAtm128GeneralIOC, HplAtm128InterruptC;
  components HplVS1011eC, VS1011eC;
  components MessageManagerC, LlcTransceiverC, IpTransceiverC, /*PingC, */new UdpC(UDP_LOCAL_PORT);
#ifndef WLAN
  components Enc28j60C as EthernetC;
#else
  components Mrf24wC as EthernetC;
#endif
  components new TimerMilliC() as TouchTimer;
  components new TimerMilliC() as CaretBlinkTimer;
  components PlatformSerialC;
  components VolumeAdcC;
  components new AdcReadClientC();
  components BusyWaitMicroC;
  JabberClientC.VolumeReading -> VolumeAdcC;
  VolumeAdcC.Read2 -> AdcReadClientC;
  /* Read<uint16_t> = AdcReadClientC; */
  AdcReadClientC.Atm128AdcConfig -> VolumeAdcC; /* used by AdcReadClientC */  
  AdcReadClientC.ResourceConfigure -> VolumeAdcC; /* used by AdcReadClientC */

  /* MAIN */

  JabberClientC.TouchTimer -> TouchTimer;
  JabberClientC.CaretBlinkTimer -> CaretBlinkTimer;
  JabberClientC.Leds -> LedsC;
  JabberClientC.LCD2 -> BufferedLcdC;
  JabberClientC.GLCD -> TouchScreenC.Glcd;
  JabberClientC.Keyboard -> KeyboardC;
  JabberClientC.TouchScreen -> TouchScreenC.TouchScreen;
  JabberClientC.MessageManager -> MessageManagerC;
  JabberClientC.MP3 -> VS1011eC;
  JabberClientC.Boot -> MainC.Boot;

  /* KEYBOARD */

  components new AsyncQueueC(uint16_t, MAX_KEYBOARD_BUFFER) as KeyboardBuffer;
  KeyboardC.Buffer -> KeyboardBuffer;
  KeyboardC.HplPS2 -> HplPS2C;
  HplPS2C.DataPort -> HplAtm128GeneralIOC.PortD4;
  HplPS2C.ClockPort -> HplAtm128GeneralIOC.PortD1;
  HplPS2C.ClockInterrupt -> HplAtm128InterruptC.Int1; /* PinD1 */
  MainC.SoftwareInit -> HplPS2C.Init;
  MainC.SoftwareInit -> KeyboardC.Init;

  /* MP3 */

  HplVS1011eC.RSTPort -> HplAtm128GeneralIOC.PortF7; /* OK */
  HplVS1011eC.CSPort -> HplAtm128GeneralIOC.PortF6; /* OK */
  HplVS1011eC.DREQPort -> HplAtm128GeneralIOC.PortD2;  /* OK */
  HplVS1011eC.BSYNCPort -> HplAtm128GeneralIOC.PortF3; /* OK */
  HplVS1011eC.DREQInterrupt -> HplAtm128InterruptC.Int2; /* OK, PortD2 */
  HplVS1011eC.DataPort -> Atm1280SpiC.SpiByte;
  HplVS1011eC.DataControl -> Atm1280SpiC.SpiControl;
  HplVS1011eC.DataPacket -> Atm1280SpiC.SpiPacket;
  HplVS1011eC.Resource -> Atm1280SpiC.Resource[unique("Atm128SpiC.Resource")];
  HplVS1011eC.ResetWaiter -> BusyWaitMicroC;
  VS1011eC.HplVS1011e -> HplVS1011eC;
  MainC.SoftwareInit -> HplVS1011eC.Init;
  
  /* UDP */

  MessageManagerC.LCD2 -> BufferedLcdC;
  MessageManagerC.UdpSend -> UdpC;
  MessageManagerC.UdpReceive -> UdpC;
  MessageManagerC.Control -> EthernetC;
  LlcTransceiverC.Mac -> EthernetC;
  MessageManagerC.IpControl -> IpTransceiverC;
#ifdef WLAN
  MessageManagerC.WlanControl -> EthernetC;
#endif
  MessageManagerC.Boot -> MainC.Boot;

}
