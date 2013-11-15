/*******************************************************************************
* File Name          : main.c
* Author             : KetilO
* Version            : V1.1.0
* Date               : 03/15/2012
* Description        : Main program body
********************************************************************************

/* Includes ------------------------------------------------------------------*/
#include "stm32f10x_lib.h"

/* Private define ------------------------------------------------------------*/
// Uncomment the clock speed you will be using
//#define STM32Clock24MHz
//#define STM32Clock28MHz
//#define STM32Clock32MHz
#define STM32Clock40MHz
//#define STM32Clock48MHz
//#define STM32Clock56MHz

#define MAXECHO           ((u16)512)
#define MAXGPS            ((u16)512)
#define MAXBLUETOOTH      ((u16)512)
#define ADC1_ICDR_Address ((u32)0x4001243C)

typedef struct
{
  vu8 Start;                                    // 0x20000000 0=Wait/Done, 1=Start, 2=In progress
  u8 PingPulses;                                // 0x20000001 Number of ping pulses (0-255)
  u8 PingTimer;                                 // 0x20000002 TIM1 auto reload value, ping frequency
  u8 RangeInx;                                  // 0x20000003 Current range index
  u16 PixelTimer;                               // 0x20000004 TIM2 auto reload value, sample rate
  vu16 EchoIndex;                               // 0x20000006 Current index into EchoArray
  u16 ADCBatt;                                  // 0x20000008 Battery
  u16 ADCWaterTemp;                             // 0x2000000A Water temprature
  u16 ADCAirTemp;                               // 0x2000000C Air temprature
  vu16 GPSHead;                                 // 0x2000000E GPSArray head, index into GPSArray
  u8 EchoArray[MAXECHO];                        // 0x20000010 Echo array
  u16 GainArray[MAXECHO];                       // 0x20000210 Gain array
  u16 GainInit[18];                             // 0x20000610 Gain setup array, first half word is initial gain
  u8 GPSArray[MAXGPS];                          // 0x20000634 GPS array, received GPS NMEA 0183 messages
  vu16 BLUETOOTHHead;                           // 0x20000834 BLUETOOTHArray head, index into BLUETOOTHArray
  u8 BLUETOOTHArray[MAXBLUETOOTH];              // 0x20000836 Bluetooth array, received bluetooth messages
}STM32_SonarTypeDef;

typedef struct
{
	u8 SatelliteID;								                // Satelite ID
	u8 Elevation;								                  // Elevation in degrees (0-90)
	u16 Azimuth;								                  // Azimuth in degrees (0-359)
	u8 SNR;									                      // Signal strenght	(0-50, 0 not tracked) 
	u8 Fixed;									                    // TRUE if used in fix
} STM32_SateliteTypeDef;

typedef struct
{
	u8 fixquality;                                // Fix quality
	u8 nsat;                                      // Number of satelites tracked
	u16 hdop;									                    // Horizontal dilution of position * 10
	u16 vdop;									                    // Vertical dilution of position * 10
	u16 pdop;									                    // Position dilution of position * 10
	u16 alt;									                    // Altitude in meters
} STM32_AltitudeTypeDef;

typedef struct
{
  u16 Lenght;                                   // 
  u16 Chksum;                                   // 
  u8 Version;                                   // 201
  u8 PingPulses;                                // Number of pulses in a ping (0 to 128)
  u16 GainSet;                                  // Gain set level (0 to 4095)
  u16 SoundSpeed;                               // Speed of sound in water
  u16 ADCBattery;                               // Battery level
  u16 ADCWaterTemp;                             // Water temprature
  u16 ADCAirTemp;                               // Air temprature
  u32 iTime;                                    // UTC Dos file time. 2 seconds resolution
  u32 iLon;                                     // Longitude, integer
  u32 iLat;                                     // Lattitude, integer
  u16 iSpeed;                                   // Speed in kts
  u16 iBear;                                    // Bearing in degrees
  STM32_SateliteTypeDef Satelite[12];           // 12 Satelites
  STM32_AltitudeTypeDef Altitude;               // Alttude + more
  u8 EchoArray[MAXECHO];                        // Echo array
} STM32_SonarDataTypeDef;

/* Private macro -------------------------------------------------------------*/
/* Private variables ---------------------------------------------------------*/
static STM32_SonarTypeDef STM32_Sonar;          // 0x20000000
static STM32_SonarDataTypeDef STM32_SonarData;
vu8 BlueLED;                                    // Current state of the blue led
vu16 Ping;                                      // Value to output to PA1 and PA2 pins
vu8 Setup;                                      // Setup mode
vu16 GPSTail;
const u8 GPSBaud[]="$PSRF100,1,9600,8,1,0*0D\r\n\0";  // Set baudrate to 9600
const u8 GPSInit[]="$PSRF103,04,00,01,00*20\r\n$PSRF103,03,00,05,00*23\r\n$PSRF103,00,00,05,00*20\r\n$PSRF103,02,00,05,00*22\r\n$PSRF103,01,00,00,00*24\r\n$PSRF103,05,00,00,00*20\r\n\0";
/* NMEA Messages */
const u8 szGPRMC[]="$GPRMC\0";
const u8 szGPGSV[]="$GPGSV\0";
const u8 szGPGGA[]="$GPGGA\0";
const u8 szGPGSA[]="$GPGSA\0";

/* Private function prototypes -----------------------------------------------*/
void RCC_Configuration(void);
void GPIO_Configuration(void);
void NVIC_Configuration(void);
void ADC_Startup(void);
void ADC_Configuration(void);
void TIM1_Configuration(void);
void TIM2_Configuration(void);
void TIM3_Configuration(void);
void USART1_Configuration(u16 Baud);
void USART3_Configuration(u16 Baud);
u16 GetADCValue(u8 Channel);
void USART1_puts(char *str);
void USART3_putdata(char *data,u16 lenght);
void GainSetup(void);
void TrimOutput(void);
void GetEcho(void);
u32 ParseGPS(void);
u8 StrCmp(u8 *str,u8 *comp);
void ParseGPRMC(u16 GPSStart);
void ParseGPGSV(u16 GPSStart);
void ParseGPGGA(u16 GPSStart);
void ParseGPGSA(u16 GPSStart);

/* Private functions ---------------------------------------------------------*/

/*******************************************************************************
* Function Name  : main
* Description    : Main program
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
int main(void)
{
  u32 i;
  STM32_SonarData.Lenght = sizeof STM32_SonarData;
  STM32_SonarData.Version = 201;
  /* System clocks configuration */
  RCC_Configuration();
  /* NVIC configuration */
  NVIC_Configuration();
  /* GPIO configuration */
  GPIO_Configuration();
  /* TIM1 configuration */
  TIM1_Configuration();
  /* TIM3 configuration */
  TIM3_Configuration();
  /* ADC1 configuration */
  ADC_Startup();
  /* ADC1 injected channel configuration */
  ADC_Configuration();
  /* Enable DAC channel1 and channel2, buffered output */
  DAC->CR = 0x10001;
  /* Set the DAC channel1 to output lowest gain */
  DAC->DHR12R1 = (u16)0x0;
  /* Set the DAC channel2 to output middle output trim */
  DAC->DHR12R2 = (u16)0x400;
  /* Setup USART1 4800 baud */
  USART1_Configuration(4800);
  /* Setup USART3 9600 baud */
  USART3_Configuration(9600);
  /* Wait until GPS module has started up */
  i = 0;
  while (i++ < 20000000)
  {
  }
  USART1_puts((char*) GPSBaud);
  i = 0;
  while (i++ < 2000000)
  {
  }
  /* Set USART1 baudrate to 9600 */
  USART1_Configuration(9600);
  i = 0;
  while (i++ < 2000000)
  {
  }
  USART1_puts((char*) GPSInit);

  Setup = 0;
  if (GPIO_ReadInputDataBit(GPIOA,GPIO_Pin_0))
  {
    /* Enable TIM3 */
    TIM_Cmd(TIM3, ENABLE);
    Setup = 1;
  }
  while (1)
  {
    if (STM32_Sonar.Start == 1)
    {
      STM32_Sonar.Start = 99;
      /* Toggle blue led */
      if (BlueLED)
      {
        GPIO_WriteBit(GPIOC, GPIO_Pin_8, Bit_RESET);
        BlueLED = 0;
      }
      else
      {
        GPIO_WriteBit(GPIOC, GPIO_Pin_8, Bit_SET);
        BlueLED = 1;
      }
      /* Setup gain array */
      GainSetup();
      /* Clear the echo array */
      i = 1;
      while (i < MAXECHO)
      {
        STM32_Sonar.EchoArray[i] = 0;
        STM32_SonarData.EchoArray[i] = 0;
        i++;
      }
      /* Read battery */
      STM32_Sonar.ADCBatt = GetADCValue(ADC_Channel_14);
      STM32_SonarData.ADCBattery = STM32_Sonar.ADCBatt;
      /* Read water temprature */
      STM32_Sonar.ADCWaterTemp = GetADCValue(ADC_Channel_6);
      STM32_SonarData.ADCWaterTemp = STM32_Sonar.ADCWaterTemp;
      /* Read air temprature */
      STM32_Sonar.ADCAirTemp = GetADCValue(ADC_Channel_7);
      STM32_SonarData.ADCAirTemp = STM32_Sonar.ADCAirTemp;
      if (Setup)
      {
        /* No ping in setup mode */
        STM32_Sonar.PingPulses = 0;
      }
      else
      {
        TrimOutput();
      }
      while (ParseGPS())
      {
      }
      /* Enable ADC injected channel */
      ADC_AutoInjectedConvCmd(ADC1, ENABLE);
      /* Set the TIM1 Autoreload value */
      TIM1->ARR = STM32_Sonar.PingTimer;
      /* Set the TIM3 Autoreload value */
      TIM3->ARR = STM32_Sonar.PingTimer*2+1;
      /* Reset TIM1 count */
      TIM1->CNT = 0;
      /* Set TIM1 repetirion counter */
      TIM1->RCR = 0;
      /* Reset echo index */
      STM32_Sonar.EchoIndex = 0;
      /* Init Ping */
      Ping = 0x2;
      /* Disable the USART1 Receive interrupt: this interrupt is generated when the 
         USART1 receive data register is not empty */
      USART_ITConfig(USART1, USART_IT_RXNE, DISABLE);
      /* Enable TIM1 */
      TIM_Cmd(TIM1, ENABLE);
      /* Get the Echo array */
      GetEcho();
      /* Store the current range as the first byte in the echo array */
      STM32_Sonar.EchoArray[0] = STM32_Sonar.RangeInx;
      STM32_SonarData.EchoArray[0] = STM32_Sonar.RangeInx;
      /* Done, Disable TIM2 */
      TIM2->CR1 = 0;
      /* Disable ADC injected channel */
      ADC_AutoInjectedConvCmd(ADC1, DISABLE);
      /* Set the DAC to output lowest gain */
      DAC->DHR12R1 = (u16)0x0;
    }
    else if (STM32_Sonar.Start == 2)
    {
      /* Send initialization data to GPS */
      // USART1_puts((char*) (u32 *)STM32_Sonar.GainArray);
      STM32_Sonar.Start=0;
    }
    else if (STM32_Sonar.Start == 3)
    {
      /* Set USART1 baudrate to 9600 */
      // USART1_Configuration(9600);
      STM32_Sonar.Start=0;
    }
    else if (STM32_Sonar.Start == 4)
    {
      /* Read battery */
      STM32_Sonar.ADCBatt = GetADCValue(ADC_Channel_14);
      /* Read water temprature */
      STM32_Sonar.ADCWaterTemp = GetADCValue(ADC_Channel_6);
      /* Read air temprature */
      STM32_Sonar.ADCAirTemp = GetADCValue(ADC_Channel_7);
      STM32_Sonar.Start=0;
    }
    i = 1000;
    while (i--);
  }
}

void TrimOutput(void)
{
  u16 Trim;
  u16 TrimAdd;
  vu32 i;

  /* Trim echo output to near zero */
  Trim = (u16)0x400;
  TrimAdd = (u16)0x200;
  while (TrimAdd)
  {
    DAC->DHR12R2 = Trim;
    i = 10000;
    while (i--);
    if (GetADCValue(ADC_Channel_3)>32)
    {
      Trim = Trim + TrimAdd;
    }
    else
    {
      Trim = Trim - TrimAdd;
    }
    TrimAdd = TrimAdd / 2;
  }
}

u8 StrCmp(u8 *str,u8 *comp)
{
  u8 c;
  while ((c = *comp++))
  {
    c = c - *str;
    if (c)
    {
      break;
    }
    *str++;
  }
  return c;
}

void ParseGPRMC(u16 GPSStart)
{
}

void ParseGPGSV(u16 GPSStart)
{
}

void ParseGPGGA(u16 GPSStart)
{
}

void ParseGPGSA(u16 GPSStart)
{
}

u32 ParseGPS(void)
{
  u16 GPSStart = -1;
  u16 GPSEnd = -1;
  u16 i = GPSTail;
  while (i != STM32_Sonar.GPSHead)
  {
    if (STM32_Sonar.GPSArray[i] == 0x24 && GPSEnd == -1)
    {
      GPSStart = i;
    }
    if (STM32_Sonar.GPSArray[i] == 0x0D && GPSStart != -1)
    {
      GPSEnd = i;
      break;
    }
    i++;
    i = i & (MAXGPS - 1);
  }
  if (GPSStart != -1 && GPSEnd != -1)
  {
    GPSTail = GPSEnd;
    if (StrCmp((u8*)&STM32_Sonar.GPSArray[GPSStart],(u8*)szGPRMC) == 0)
    {
      ParseGPRMC(GPSStart);
    }
    else if (StrCmp((u8*)&STM32_Sonar.GPSArray[GPSStart],(u8*)szGPGSV) == 0)
    {
      ParseGPGSV(GPSStart);
    }
    else if (StrCmp((u8*)&STM32_Sonar.GPSArray[GPSStart],(u8*)szGPGGA) == 0)
    {
      ParseGPGGA(GPSStart);
    }
    else if (StrCmp((u8*)&STM32_Sonar.GPSArray[GPSStart],(u8*)szGPGSA) == 0)
    {
      ParseGPGSA(GPSStart);
    }
    return 1;
  }
  return 0;
}

void GetEcho(void)
{
  u32* ADC;
  u8 Echo;

  /* Get pointer to injected channel */
  ADC = ( (u32 *) ADC1_ICDR_Address);
  while (STM32_Sonar.Start)
  {
    /* To eliminate the need for an advanced AM demodulator the largest */ 
    /* ADC reading is stored in its echo array element */
    /* Get echo */
    Echo = ( (*(u32*) (((*(u32*)&ADC)))) >> 4);
    /* If echo larger than previous echo then update the echo array */
    if (Echo > STM32_Sonar.EchoArray[STM32_Sonar.EchoIndex])
    {
      STM32_Sonar.EchoArray[STM32_Sonar.EchoIndex] = Echo;
      STM32_SonarData.EchoArray[STM32_Sonar.EchoIndex] = Echo;
    }
  }
}

/*******************************************************************************
* Function Name  : GetADCValue
* Description    : This function sums 16 ADC conversions and returns the average.
* Input          : ADC channel
* Output         : None
* Return         : The ADC cannel reading
*******************************************************************************/
u16 GetADCValue(u8 Channel)
{
  vu8 i;
  vu16 ADCValue;
  ADC_InitTypeDef ADC_InitStructure;

  ADCValue = 0;
  ADC_InitStructure.ADC_Mode = ADC_Mode_Independent;
  ADC_InitStructure.ADC_ScanConvMode = ENABLE;
  ADC_InitStructure.ADC_ContinuousConvMode = ENABLE;
  ADC_InitStructure.ADC_ExternalTrigConv = ADC_ExternalTrigConv_None;
  ADC_InitStructure.ADC_DataAlign = ADC_DataAlign_Right;
  ADC_InitStructure.ADC_NbrOfChannel = 1;
  ADC_Init(ADC1, &ADC_InitStructure);
  /* ADC1 regular channel configuration */ 
  ADC_RegularChannelConfig(ADC1, Channel, 1, ADC_SampleTime_239Cycles5);
  /* Start ADC1 Software Conversion */ 
  ADC_SoftwareStartConvCmd(ADC1, ENABLE);
  /* Add 16 conversions to reduce thermal noise */
  i = 16;
  while (i--)
  {
    ADC_ClearFlag(ADC1, ADC_FLAG_EOC);
    while (ADC_GetFlagStatus(ADC1, ADC_FLAG_EOC) == RESET)
    {
    }
    ADCValue += ADC1->DR;
  }
  /* Stop ADC1 Software Conversion */ 
  ADC_SoftwareStartConvCmd(ADC1, DISABLE);
  /* Return average of the 16 added conversions */
  return (ADCValue >> 4);
}

/*******************************************************************************
* Function Name  : GainSetup
* Description    : This function sets up the gain levels for each pixel
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void GainSetup(void)
{
  vu32 GainInitInx;
  vu32 i;
  vu32 GainInx;
  vu32 GainInc;
  vu32 GainVal;
  GainInitInx=1;
  GainInx=0;
  while (GainInitInx<17)
  {
    GainVal=STM32_Sonar.GainInit[GainInitInx]<<13;
    GainInc=(STM32_Sonar.GainInit[GainInitInx+1]-STM32_Sonar.GainInit[GainInitInx])<<8;
    i=0;
    while (i<32)
    {
      STM32_Sonar.GainArray[GainInx]=(GainVal>>13)+STM32_Sonar.GainInit[0];
      if ((GainVal>>12) && 1)
      {
        STM32_Sonar.GainArray[GainInx]++;
      }
      if (STM32_Sonar.GainArray[GainInx]>4095)
      {
        STM32_Sonar.GainArray[GainInx]=4095;
      }
      GainVal+=GainInc;
      GainInx++;
      i++;
    }
    GainInitInx++;
  }
}

/*******************************************************************************
* Function Name  : TIM1_UP_IRQHandler
* Description    : This function handles TIM1 global interrupt request.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void TIM1_UP_IRQHandler(void)
{
  /* Set ping outputs high (FET's off) */
  GPIOA->BSRR = (u16) (GPIO_Pin_2 | GPIO_Pin_1);
  if (STM32_Sonar.PingPulses)
  {
    GPIOA->ODR = Ping;
    if (Ping == 0x2)
    {
      Ping = 0x4;     // PA02
    }
    else
    {
      Ping = 0x2;     // PA01
      STM32_Sonar.PingPulses--;
    }
  }
  else
  {
    /* Ping done, Disable TIM1 */
    TIM_Cmd(TIM1, DISABLE);
    /* TIM2 configuration */
    TIM2_Configuration();
    /* Clear TIM2 Update interrupt pending bit */
    TIM2->SR = (u16)~TIM_IT_Update;
    /* Enable TIM2 */
    TIM_Cmd(TIM2, ENABLE);
    /* Enable the USART1 Receive interrupt: this interrupt is generated when the 
       USART1 receive data register is not empty */
    USART_ITConfig(USART1, USART_IT_RXNE, ENABLE);
  }
  /* Clear TIM1 Update interrupt pending bit */
  TIM1->SR = (u16)~TIM_IT_Update;
}

/*******************************************************************************
* Function Name  : TIM2_IRQHandler
* Description    : This function handles TIM2 global interrupt request.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void TIM2_IRQHandler(void)
{
  /* Clear TIM2 Update interrupt pending bit */
  asm("mov    r0,#0x40000000");               /* TIM2 */
  asm("strh   r0,[r0,#0x8 *2]");              /* TIM2->SR */

  /* Increment the echo array index */
  asm("mov    r1,#0x20000000");               /* STM32_Sonar */
  asm("ldrh   r2,[r1,#0x6]");                 /* STM32_Sonar.EchoIndex */
  asm("add    r2,r2,#0x1");
  asm("cmp    r2,#0x200");
  asm("ite    ne");
  asm("strhne r2,[r1,#0x6]");                 /* Update STM32_Sonar.EchoIndex */
  asm("strbeq r2,[r1,#0x0]");                 /* Reset STM32_Sonar.Start */

  /* Update the DAC to output next gain level */
  asm("movw   r0,#0x7400");                   /* DAC1 */
  asm("movt   r0,#0x4000");
  asm("add    r2,r2,0x108");
  asm("ldrh   r3,[r1,r2,lsl #0x1]");
  asm("strh   r3,[r0,#0x8]");                 /* DAC_DHR12R1 */
}

/*******************************************************************************
* Function Name  : USART1_puts
* Description    : This function transmits a zero terminated string
* Input          : Zero terminated string
* Output         : None
* Return         : None
*******************************************************************************/
void USART1_puts(char *str)
{
  char c;
  /* Characters are transmitted one at a time. */
  while ((c = *str++))
  {
    /* Wait until transmit register empty */
    while((USART1->SR & USART_FLAG_TXE) == 0);          
    /* Transmit Data */
    USART1->DR = (u16)c;
  }
}

/*******************************************************************************
* Function Name  : USART3_putdata
* Description    : This function transmits data
* Input          : data, lenght
* Output         : None
* Return         : None
*******************************************************************************/
void USART3_putdata(char *data,u16 lenght)
{
  char c;
  /* Characters are transmitted one at a time. */
  while (lenght--)
  {
    /* Wait until transmit register empty */
    while((USART3->SR & USART_FLAG_TXE) == 0);          
    /* Transmit Data */
    USART3->DR = (u16)c;
    *data++;
  }
}

/*******************************************************************************
* Function Name  : USART1_IRQHandler
* Description    : This function handles USART1 global interrupt request.
*                  An interrupt is generated when a character is recieved.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void USART1_IRQHandler(void)
{
  /* Get pointer to USART1->DR */
  asm("movw   r0,#0x3800");
  asm("movt   r0,#0x4001");
  /* Get recieved halfword */
  asm("ldrh   r3,[r0,#0x2*2]");
  /* Get pointer to STM32_Sonar */
  asm("mov    r0,#0x20000000");
  /* Get GPSHead value */
  asm("ldrh   r2,[r0,#0x7*2]");
  /* Get offset to GPSArray */
  asm("movw   r1,#0x634");
  /* Get pointer to GPSArray */
  asm("add    r1,r1,r0");
  /* Store received byte at GPSArray[GPSHead] */
  asm("strb   r3,[r1,r2]");
  /* Increment GPSHead */
  asm("add    r2,r2,#0x1");
  /* Limit GPSHead to 512 bytes*/
  asm("mov    r2,r2,lsl #23");
  asm("mov    r2,r2,lsr #23");
  /* Store GPSHead */
  asm("strh   r2,[r0,#0x7*2]");

  // STM32_Sonar.GPSArray[STM32_Sonar.GPSHead++]=USART1->DR;
  // /* Limit GPSHead to 512 bytes array*/
  // STM32_Sonar.GPSHead&=MAXGPS-1;
}

/*******************************************************************************
* Function Name  : USART3_IRQHandler
* Description    : This function handles USART3 global interrupt request.
*                  An interrupt is generated when a character is recieved.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void USART3_IRQHandler(void)
{
  /* Get pointer to USART3->DR */
  asm("movw   r0,#0x4800");
  asm("movt   r0,#0x4000");
  /* Get recieved halfword */
  asm("ldrh   r3,[r0,#0x2*2]");
  /* Get pointer to STM32_Sonar */
  asm("mov    r0,#0x20000000");
  /* Get BLUETOOTHHead value */
  asm("ldrh   r2,[r0,#0x834]");
  /* Get offset to BLUETOOTHArray */
  asm("movw   r1,#0x836");
  /* Get pointer to BLUETOOTHArray */
  asm("add    r1,r1,r0");
  /* Store received byte at GPSArray[GPSHead] */
  asm("strb   r3,[r1,r2]");
  /* Increment BLUETOOTHHead */
  asm("add    r2,r2,#0x1");
  /* Limit BLUETOOTHHead to 512 bytes*/
  asm("mov    r2,r2,lsl #23");
  asm("mov    r2,r2,lsr #23");
  /* Store BLUETOOTHHead */
  asm("strh   r2,[r0,#0x834]");

  // STM32_Sonar.BLUETOOTHArray[STM32_Sonar.BLUETOOTHHead++]=USART3->DR;
  // /* Limit BLUETOOTHHead to 512 bytes array*/
  // STM32_Sonar.BLUETOOTHHead&=MAXBLUETOOTH-1;
}

/*******************************************************************************
* Function Name  : ADC_Startup
* Description    : This function calibrates ADC1.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void ADC_Startup(void)
{
  ADC_InitTypeDef ADC_InitStructure;
  /* ADCCLK = PCLK2/2 */
  RCC_ADCCLKConfig(RCC_PCLK2_Div2);
  /* ADC1 configuration ------------------------------------------------------*/
  ADC_InitStructure.ADC_Mode = ADC_Mode_Independent;
  ADC_InitStructure.ADC_ScanConvMode = ENABLE;
  ADC_InitStructure.ADC_ContinuousConvMode = ENABLE;
  ADC_InitStructure.ADC_ExternalTrigConv = ADC_ExternalTrigConv_None;
  ADC_InitStructure.ADC_DataAlign = ADC_DataAlign_Right;
  ADC_InitStructure.ADC_NbrOfChannel = 1;
  ADC_Init(ADC1, &ADC_InitStructure);
  /* ADC1 regular channel2 configuration */ 
  ADC_RegularChannelConfig(ADC1, ADC_Channel_3, 1, ADC_SampleTime_55Cycles5);
  /* Enable ADC1 */
  ADC_Cmd(ADC1, ENABLE);
  /* Enable ADC1 reset calibaration register */   
  ADC_ResetCalibration(ADC1);
  /* Check the end of ADC1 reset calibration register */
  while(ADC_GetResetCalibrationStatus(ADC1));
  /* Start ADC1 calibaration */
  ADC_StartCalibration(ADC1);
  /* Check the end of ADC1 calibration */
  while(ADC_GetCalibrationStatus(ADC1));
}

/*******************************************************************************
* Function Name  : ADC_Configuration
* Description    : This function prepares ADC1 for Injected conversion
*                  on channel 2.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void ADC_Configuration(void)
{
  ADC_InitTypeDef ADC_InitStructure;

  /* ADCCLK = PCLK2/2 */
  RCC_ADCCLKConfig(RCC_PCLK2_Div2);
  ADC_InitStructure.ADC_Mode = ADC_Mode_Independent;
  ADC_InitStructure.ADC_ScanConvMode = ENABLE;
  ADC_InitStructure.ADC_ContinuousConvMode = ENABLE;
  ADC_InitStructure.ADC_ExternalTrigConv = ADC_ExternalTrigConv_None;
  ADC_InitStructure.ADC_DataAlign = ADC_DataAlign_Right;
  /* ADC1 single channel configuration */
  ADC_InitStructure.ADC_NbrOfChannel = 1;
  ADC_Init(ADC1, &ADC_InitStructure);
  /* Setup injected channel */
  ADC_InjectedSequencerLengthConfig(ADC1,1);
  /* Sonar echo */
  ADC_InjectedChannelConfig(ADC1,ADC_Channel_3,1,ADC_SampleTime_1Cycles5);
}

/*******************************************************************************
* Function Name  : RCC_Configuration
* Description    : Configures the different system clocks.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void RCC_Configuration(void)
{
  ErrorStatus HSEStartUpStatus;
  /* RCC system reset(for debug purpose) */
  RCC_DeInit();
  /* Enable HSE */
  RCC_HSEConfig(RCC_HSE_ON);
  /* Wait till HSE is ready */
  HSEStartUpStatus = RCC_WaitForHSEStartUp();
  if(HSEStartUpStatus == SUCCESS)
  {
    /* Enable Prefetch Buffer */
    FLASH_PrefetchBufferCmd(FLASH_PrefetchBuffer_Enable);
    /* Flash 2 wait state */
    FLASH_SetLatency(FLASH_Latency_0);
    /* HCLK = SYSCLK */
    RCC_HCLKConfig(RCC_SYSCLK_Div1); 
    /* PCLK2 = HCLK */
    RCC_PCLK2Config(RCC_HCLK_Div1); 
    /* PCLK1 = HCLK */
    RCC_PCLK1Config(RCC_HCLK_Div1);
    /* ADCCLK = PCLK2/2 */
    RCC_ADCCLKConfig(RCC_PCLK2_Div2);
#ifdef STM32Clock24MHz
    /* PLLCLK = 8MHz * 3 = 24 MHz */
    RCC_PLLConfig(RCC_PLLSource_HSE_Div1, RCC_PLLMul_3);
#endif
#ifdef STM32Clock28MHz
    /* PLLCLK = 8MHz / 2 * 7 = 28 MHz */
    RCC_PLLConfig(RCC_PLLSource_HSE_Div2, RCC_PLLMul_7);
#endif
#ifdef STM32Clock32MHz
    /* PLLCLK = 8MHz * 4 = 32 MHz */
    RCC_PLLConfig(RCC_PLLSource_HSE_Div1, RCC_PLLMul_4);
#endif
#ifdef STM32Clock40MHz
    /* PLLCLK = 8MHz * 5 = 40 MHz */
    RCC_PLLConfig(RCC_PLLSource_HSE_Div1, RCC_PLLMul_5);
#endif
#ifdef STM32Clock48MHz
    /* PLLCLK = 8MHz * 6 = 48 MHz */
    RCC_PLLConfig(RCC_PLLSource_HSE_Div1, RCC_PLLMul_6);
#endif
#ifdef STM32Clock56MHz
    /* PLLCLK = 8MHz * 7 = 56 MHz */
    RCC_PLLConfig(RCC_PLLSource_HSE_Div1, RCC_PLLMul_7);
#endif
    /* Enable PLL */ 
    RCC_PLLCmd(ENABLE);
    /* Wait till PLL is ready */
    while(RCC_GetFlagStatus(RCC_FLAG_PLLRDY) == RESET)
    {
    }
    /* Select PLL as system clock source */
    RCC_SYSCLKConfig(RCC_SYSCLKSource_PLLCLK);
    /* Wait till PLL is used as system clock source */
    while(RCC_GetSYSCLKSource() != 0x08)
    {
    }
    /* Enable TIM1, ADC1, USART1, GPIOA, GPIOB and GPIOC peripheral clocks */
    RCC_APB2PeriphClockCmd(RCC_APB2Periph_TIM1 | RCC_APB2Periph_ADC1 | RCC_APB2Periph_USART1 | RCC_APB2Periph_GPIOA | RCC_APB2Periph_GPIOB | RCC_APB2Periph_GPIOC, ENABLE);
    /* Enable DAC, TIM2 and TIM3 peripheral clocks */
    RCC_APB1PeriphClockCmd(RCC_APB1Periph_DAC | RCC_APB1Periph_TIM2 | RCC_APB1Periph_TIM3 | RCC_APB1Periph_USART3, ENABLE);
  }
}

/*******************************************************************************
* Function Name  : GPIO_Configuration
* Description    : Configures the different GPIO ports.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void GPIO_Configuration(void)
{
  GPIO_InitTypeDef GPIO_InitStructure;
  /* Set ping outputs high (FET's off) */
  GPIO_WriteBit(GPIOA, GPIO_Pin_2 | GPIO_Pin_1, Bit_SET);
  /* Configure PA.02 and PA.01 as outputs */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_2 | GPIO_Pin_1;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_Out_PP;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOA, &GPIO_InitStructure);
  /* Configure ADC Channel7 (PA.07), ADC Channel6 (PA.06), DAC Channel2 (PA.05), DAC Channel1 (PA.04) and ADC Channel3 (PA.03) as analog input */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_7 | GPIO_Pin_6 | GPIO_Pin_5 | GPIO_Pin_4 | GPIO_Pin_3;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AIN;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOA, &GPIO_InitStructure);
  /* Configure ADC Channel14 (PC.04) */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_4;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AIN;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOC, &GPIO_InitStructure);
  /* Configure PA9 USART1 Tx as alternate function push-pull */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
  GPIO_Init(GPIOA, &GPIO_InitStructure);
  /* Configure PA10 USART1 Rx as input floating */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_10;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN_FLOATING;
  GPIO_Init(GPIOA, &GPIO_InitStructure);
  /* Configure PC.09 (LED3) and PC.08 (LED4) as output */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_9 | GPIO_Pin_8;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_Out_PP;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOC, &GPIO_InitStructure);
  /* TIM3 channel 3 pin (PB0) configuration */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_0;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOB, &GPIO_InitStructure);
  /* Configure PB10 USART3 Tx as alternate function push-pull */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_10;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
  GPIO_Init(GPIOB, &GPIO_InitStructure);
  /* Configure PB11 USART3 Rx as input floating */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_11;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN_FLOATING;
  GPIO_Init(GPIOB, &GPIO_InitStructure);
  /* Configure PB14 USART3 RTS as alternate function push-pull */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_14;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_AF_PP;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOB, &GPIO_InitStructure);
  /* Configure PB13 USART3 CTS as input floating */
  GPIO_InitStructure.GPIO_Pin = GPIO_Pin_13;
  GPIO_InitStructure.GPIO_Mode = GPIO_Mode_IN_FLOATING;
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_50MHz;
  GPIO_Init(GPIOB, &GPIO_InitStructure);
}

/*******************************************************************************
* Function Name  : NVIC_Configuration
* Description    : Configures Vector Table base location.
*                  Configures interrupts.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void NVIC_Configuration(void)
{
  NVIC_InitTypeDef NVIC_InitStructure;
  /* Set the Vector Table base location at 0x08000000 */ 
  NVIC_SetVectorTable(NVIC_VectTab_FLASH, 0x0);   
  /* Enable the TIM1 global Interrupt */
  NVIC_InitStructure.NVIC_IRQChannel = TIM1_UP_IRQChannel;
  NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;
  NVIC_Init(&NVIC_InitStructure);
  /* Enable the TIM2 global Interrupt */
  NVIC_InitStructure.NVIC_IRQChannel = TIM2_IRQChannel;
  NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;
  NVIC_Init(&NVIC_InitStructure);
  /* Enable USART1 interrupt */
  NVIC_InitStructure.NVIC_IRQChannel = USART1_IRQChannel;
  NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 1;
  NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;
  NVIC_Init(&NVIC_InitStructure);
  /* Enable USART3 interrupt */
  NVIC_InitStructure.NVIC_IRQChannel = USART3_IRQChannel;
  NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 1;
  NVIC_InitStructure.NVIC_IRQChannelSubPriority = 0;
  NVIC_InitStructure.NVIC_IRQChannelCmd = ENABLE;
  NVIC_Init(&NVIC_InitStructure);
}

/*******************************************************************************
* Function Name  : TIM1_Configuration
* Description    : Configures TIM1 to count up and generate interrupt on overflow
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void TIM1_Configuration(void)
{
  TIM_TimeBaseInitTypeDef  TIM_TimeBaseStructure;
  TIM_TimeBaseStructure.TIM_ClockDivision = 0;
  TIM_TimeBaseStructure.TIM_Prescaler = 0;
  TIM_TimeBaseStructure.TIM_CounterMode = TIM_CounterMode_Up;
  /* Time base configuration 56MHz clock */
  //TIM_TimeBaseStructure.TIM_Period = 139;
  /* Time base configuration 48MHz clock */
  //TIM_TimeBaseStructure.TIM_Period = 119;
  /* Time base configuration 40MHz clock */
  TIM_TimeBaseStructure.TIM_Period = 99;
  TIM_TimeBaseStructure.TIM_RepetitionCounter = 0;
  TIM_TimeBaseInit(TIM1, &TIM_TimeBaseStructure);
  /* Enable TIM1 Update interrupt */
  TIM_ClearITPendingBit(TIM1,TIM_IT_Update);
  TIM_ITConfig(TIM1, TIM_IT_Update, ENABLE);
}

/*******************************************************************************
* Function Name  : TIM2_Configuration
* Description    : Configures TIM2 to count up and generate interrupt on overflow
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void TIM2_Configuration(void)
{
  TIM_TimeBaseInitTypeDef TIM_TimeBaseStructure;
  TIM_TimeBaseStructure.TIM_ClockDivision = 0;
  TIM_TimeBaseStructure.TIM_Prescaler = 0;
  TIM_TimeBaseStructure.TIM_Period = STM32_Sonar.PixelTimer;
  TIM_TimeBaseStructure.TIM_CounterMode = TIM_CounterMode_Up;
  TIM_TimeBaseStructure.TIM_RepetitionCounter = 0;
  TIM_TimeBaseInit(TIM2, &TIM_TimeBaseStructure);
  /* Enable TIM2 Update interrupt */
  TIM_ClearITPendingBit(TIM2,TIM_IT_Update);
  TIM_ITConfig(TIM2, TIM_IT_Update, ENABLE);
}

/*******************************************************************************
* Function Name  : TIM3_Configuration
* Description    : Configures TIM3 to count up and generate PWM output on PB0
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void TIM3_Configuration(void)
{
  TIM_TimeBaseInitTypeDef  TIM_TimeBaseStructure;
  TIM_OCInitTypeDef  TIM_OCInitStructure;
  TIM_TimeBaseStructure.TIM_ClockDivision = 0;
  TIM_TimeBaseStructure.TIM_Prescaler = 0;
  TIM_TimeBaseStructure.TIM_CounterMode = TIM_CounterMode_Up;
  /* Time base configuration 56MHz clock */
  //TIM_TimeBaseStructure.TIM_Period = 139;
  /* Time base configuration 48MHz clock */
  //TIM_TimeBaseStructure.TIM_Period = 119;
  /* Time base configuration 40MHz clock */
  TIM_TimeBaseStructure.TIM_Period = 199;
  TIM_TimeBaseStructure.TIM_RepetitionCounter = 0;
  TIM_TimeBaseInit(TIM3, &TIM_TimeBaseStructure);
  /* PWM1 Mode configuration: Channel3 */
  TIM_OCInitStructure.TIM_OCMode = TIM_OCMode_PWM1;
  TIM_OCInitStructure.TIM_OutputState = TIM_OutputState_Enable;
  TIM_OCInitStructure.TIM_OutputNState = TIM_OutputState_Disable;
  TIM_OCInitStructure.TIM_Pulse = 99;
  TIM_OCInitStructure.TIM_OCPolarity = TIM_OCPolarity_High;
  TIM_OCInitStructure.TIM_OCNPolarity = TIM_OCPolarity_Low;
  TIM_OCInitStructure.TIM_OCIdleState = TIM_OCIdleState_Reset;
  TIM_OCInitStructure.TIM_OCNIdleState = TIM_OCIdleState_Reset;
  TIM_OC3Init(TIM3, &TIM_OCInitStructure);
  TIM_OC1PreloadConfig(TIM3, TIM_OCPreload_Enable);
  TIM_ARRPreloadConfig(TIM3, ENABLE);
  /* TIM3 Main Output Enable */
  TIM_CtrlPWMOutputs(TIM3, ENABLE);
}

/*******************************************************************************
* Function Name  : USART1_Configuration
* Description    : Configures USART1 Rx and Tx for communication with GPS module.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void USART1_Configuration(u16 BaudRate)
{
  /* USART1 configured as follow:
        - BaudRate = 1200,2400,4800,9600,19200 or 38400 baud  
        - Word Length = 8 Bits
        - One Stop Bit
        - No parity
        - Hardware flow control disabled
        - Receive and transmit enabled
  */
  USART_InitTypeDef USART_InitStructure;

  USART_DeInit(USART1);
  USART_InitStructure.USART_BaudRate = BaudRate;
  USART_InitStructure.USART_WordLength = USART_WordLength_8b;
  USART_InitStructure.USART_StopBits = USART_StopBits_1;
  USART_InitStructure.USART_Parity = USART_Parity_No ;
  USART_InitStructure.USART_HardwareFlowControl = USART_HardwareFlowControl_None;
  USART_InitStructure.USART_Mode = USART_Mode_Rx | USART_Mode_Tx;
  USART_Init(USART1, &USART_InitStructure);
  /* Enable the USART Receive interrupt: this interrupt is generated when the 
     USART1 receive data register is not empty */
  USART_ITConfig(USART1, USART_IT_RXNE, ENABLE);
  /* Enable the USART1 */
  USART_Cmd(USART1, ENABLE);
}

/*******************************************************************************
* Function Name  : USART3_Configuration
* Description    : Configures USART3 Rx and Tx for communication with Bluetooth module.
* Input          : None
* Output         : None
* Return         : None
*******************************************************************************/
void USART3_Configuration(u16 BaudRate)
{
  /* USART3 configured as follow:
        - BaudRate = 1200,2400,4800,9600,19200 or 38400 baud  
        - Word Length = 8 Bits
        - One Stop Bit
        - No parity
        - Hardware flow control enabled
        - Receive and transmit enabled
  */
  USART_InitTypeDef USART_InitStructure;

  USART_DeInit(USART3);
  USART_InitStructure.USART_BaudRate = BaudRate;
  USART_InitStructure.USART_WordLength = USART_WordLength_8b;
  USART_InitStructure.USART_StopBits = USART_StopBits_1;
  USART_InitStructure.USART_Parity = USART_Parity_No ;
  USART_InitStructure.USART_HardwareFlowControl = USART_HardwareFlowControl_RTS_CTS;
  USART_InitStructure.USART_Mode = USART_Mode_Rx | USART_Mode_Tx;
  USART_Init(USART3, &USART_InitStructure);
  /* Enable the USART Receive interrupt: this interrupt is generated when the 
     USART3 receive data register is not empty */
  USART_ITConfig(USART3, USART_IT_RXNE, ENABLE);
  /* Enable the USART3 */
  USART_Cmd(USART3, ENABLE);
}

/*****END OF FILE****/
