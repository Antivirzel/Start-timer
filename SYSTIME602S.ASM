;*********************************************************************
;*.DEVICE AT90S8515                                                  *
;*********************************************************************
;* ПРОЕКТ        - ЛЫЖНЫЙ СТАДИОН 6  (С ЧИПАМИ И СИМВОЛЬНЫМ ТАБЛОМ)  *
;*********************************************************************
;* ПРОГРАММА     - СИСТЕМНЫЙ ТАЙМЕР    ВЕРСИЯ 602s                   *
;*********************************************************************
;* ФУНКЦИИ       - опрос устройств нижнего уровня                    *
;*		 - ответ на запросы устройств верхнего уровня        *
;*		 - фиксирование событий по собственному таймеру      *
;*		 - ведение и хранение протокола                      *
;*********************************************************************
;* ПЕРИФЕРИЯ     -                                                   *
;*		 - ПАМЯТЬ AT24c64 , ТАЙМЕР IIS                       *         *
;*********************************************************************
;*  НЕСУЧАЯ ЧАСТОТА                   8 МГц                          *
;*********************************************************************
;* ПОДКЛЮЧЕНИЕ БИБЛИОТЕКИ                                            *
.nolist
.include "8515def.inc"
.list
;*********************************************************************
; РЕГИСТРЫ И КОНСТАНТЫ
.def    soun   = r4             ; 
.def    count3 = r5             ; регистр счетчика 3 опросов
.def    rc2    = r6             ; регистр счетчиков разных
.def    rc1    = r7             ; регистр счетчиков разных
.def    rc     = r8             ; регистр счетчиков разных
.def    fadr2  = r9             ; регистры обращения к IIS
.def    fadr1  = r10            ; регистры обращения к IIS
.def    fdata  = r11            ; регистры обращения к IIS
.def    RZ1    = r12
.def    RZ2    = r13
.def    RZ3    = r14
.def    RZ4    = r15
;-----------------------------------------------------------------------
.def    wreg   = r16            ; перекладной регистр
.def    bufer  = r17            ; буфер на все
.def    rsa    = r18            ; регистр обращения к IIS
.def    crc    = r19            ; контрольная сумма
.def    arif1  = r20
.def    arif2  = r21
.def    fl     = r22            ; первый собственный регистр флагов
.def    rs232  = r23
.def    word   = r24            ; младший регистр слова для ар. операций
.def    wordh  = r25            ; старший регистр слова для ар. операций
;=======================================================================
; ЯЧЕЙКИ СОЗУ
.equ    reg1  = $60             ; ячейки для запись в память страницей
.equ    reg2  = $61             ; 32 байт можем записать одновременно
.equ    reg3  = $62
.equ    reg4  = $63
.equ    reg5  = $64
.equ    reg6  = $65
.equ    reg7  = $66
.equ    reg8  = $67
.equ    reg32 = $7F
.equ    reg33 = $80            ; используется только для тормоза
.equ    reg64 = $9F
.equ    reg65 = $A0            ; используется только для тормоза
;========================================================================
.equ    sob1   = $A0           ; событие, записываемое
.equ    sob2   = $A1

.equ    tsob1  = $A2           ; событие передаваемое
.equ    tsob2  = $A3
;=======================================================================
.equ    rh     = $A4
.equ    rm1    = $A5
.equ    rm2    = $A6
.equ    rs1    = $A7
.equ    rs2    = $A8
.equ    rd     = $A9
;=======================================================================
.equ    th     = $AA
.equ    tm1    = $AB
.equ    tm2    = $AC
.equ    ts1    = $AD
.equ    ts2    = $AE
.equ    td     = $AF
;=======================================================================
.equ    psth     = $BA
.equ    pstm1    = $BB
.equ    pstm2    = $BC
.equ    psts1    = $BD
.equ    psts2    = $BE
.equ    pstd     = $BF
;=======================================================================
; ЯЧЕЙКИ СОСТОЯНИЯ УСТРОЙСТВ
.equ    sostturn    = $B0
.equ    sostfin1    = $B1
.equ    sostfin2    = $B2
.equ    sostpult    = $B3
.equ    sosttab     = $B4
.equ    sostpist    = $B5
;=======================================================================
.equ    regcom1   = $C1
.equ    regcom2   = $C2
.equ    regcom3   = $C3
.equ    regcom4   = $C4
.equ    regcom5   = $C5
.equ    regcom6   = $C6
.equ    regcom7   = $C7
.equ    regcom8   = $C8
.equ    regcom9   = $C9
.equ    regcom10  = $CA
.equ    regcom11  = $CB
.equ    regcom12  = $CC
.equ    regcom13  = $CD
.equ    regcom14  = $CE
.equ    regcom15  = $CF
;--------------------------------------------------------------
; место текущего в байтах
.equ    plL    = $D0
.equ    plH    = $D1
; место текущего в тетрадах
.equ    pl1    = $D2
.equ    pl2    = $D3
.equ    pl3    = $D4
;=======================================================================
; биты порта B, отвечающие за IIS
.equ    SCL  = 6
.equ    SDA  = 7
;********************************************************************
; СОБСТВЕННЫЕ ФЛАГИ:
;                     fl,3
.equ    BIGP = 0      ; флаг большой страницы
.equ    TX9  = 1      ; флаг девятого бита ( что стоит - то передаем)
.equ    ERRCOM = 2    ; флаг недожидания
.equ    ZAPCONF = 3   ; флаг запроса конфигурации
.equ    TIMEZ   = 4   ; флаг запущенного времени
.equ    ERCOM   = 5   ; флаг ошибки приема cнизу
;*********************************************************************
.CSEG
;*****************ВЕКТОРА СБРОСА И ПРЕРЫВАНИЙ*************************
.org 0x0
st_prog:
	rjmp RESET ;
.org    INT0addr	;ВНЕШНЕЕ ПРЕРЫВАНИЕ 0
	reti
.org    INT1addr	;ВНЕШНЕЕ ПРЕРЫВАНИЕ 1
	reti
.org    ICP1addr        ;ЗАХВАТ ТАЙМЕРА\СЧЕТЧИКА 1
	reti
.org	OC1Aaddr	;Output Compare1A Interrupt Vector Address
	reti
.org	OC1Baddr	;Output Compare1B Interrupt Vector Address
	reti
.org    OVF1addr	;ПЕРЕПОЛНЕНИЕ ТАЙМЕРА\СЧЕТЧИКА 1
	reti
.org    OVF0addr	;ПЕРЕПОЛНЕНИЕ ТАЙМЕРА\СЧЕТЧИКА 0
	rjmp	inv_sound
.org    SPIaddr 	;ЗАВЕРШЕНИЕ ПЕРЕСЫЛКИ SPI
	reti
.org    URXCaddr	;ЗАВЕРШЕНИЕ ПРИЕМА UART
	reti
.org    UDREaddr	;РЕГИСТР ДАННЫХ UART ПУСТ
	reti
.org    UTXCaddr	;ЗАВЕРШЕНИЕ ПЕРЕДАЧИ UART
	reti
.org    ACIaddr 	;ПРЕРЫВАНИЕ ОТ АНАЛОГОВОГО КОМПАРАТОРА
	reti
;*********************************************************************
;***********************НАЧАЛО ОСНОВНОЙ ПРОГРАММЫ*********************
;*********************************************************************
RESET:  cli                       ;  запрет всех прерываний

	ldi     wreg,$5F          ;  загрузка стэка
       	out     SPL,wreg

	ldi     wreg,$02          ;  загрузка стэка
       	out     SPH,wreg
;----------------------------------------
	ldi     wreg,$80          ;  отключение компаратора
	out     ACSR,wreg

	ldi     wreg,$7B          ;  разрешение SLEEP-режима
	out     MCUCR,wreg        ;  INT0 - по фронту

	ldi     wreg,$0E          ;  WDT на 1 с. с запретом сброса
	out     WDTCR,wreg
;*******************************************************************
;****************НАСТРОЙКА ПОРТОВ И ПЕРИФЕРИИ***********************
;*******************************************************************
; ПОРТ А
	ldi	wreg,$FF        ; А.0 - А.7 - настроены на работу
	out	DDRA,wreg       ;             с несуществующим ОЗУ
	ldi	wreg,$00	;
	out	PORTA,wreg 	;
;===================================================================
; ПОРТ B
	ldi	wreg,$EE        ; B.0  - RXD вниз  В.1  - TXD вниз
	out	DDRB,wreg       ; В.2 - 3 - выходы управления ADM485
	ldi	wreg,$D2     	; B.6 - 7 - IIS
	out	PORTB,wreg 	; B.4 - шлейф
				; B.5 - выход звука
;===================================================================
; ПОРТ С                        ;
	ldi	wreg,$FF        ; C.0 - C.7 - настроены на работу
	out	DDRC,wreg       ;             с несуществующим ОЗУ
	ldi	wreg,$00
	out	PORTC,wreg
;===================================================================
; ПОРТ Д                        ; ИНТЕРФЕЙСЫ
	ldi	wreg,$D2        ; D.0-D.1 -   UART вверх
	out	DDRD,wreg       ; D.2     -   вход секунды
	ldi	wreg,$EE        ; D.4- выход , 0
	out	PORTD,wreg 	; D.6-D.7 -   1 - состояние покоя
;===================================================================
; НАСТРОЙКА UART                UDR  USR  UCR  UBRR
	ldi     wreg,$00
	out     USR,wreg
;------------------------------
; разрешение приема-передачи, 8 бит, неразрешение прерывания от приемника
	ldi     wreg,$19        ; 0 0 0 1 1 0 0 1
	out     UCR,wreg
;------------------------------
	ldi     wreg,12         ; скорость 38400 бод
	out     UBRR,wreg
;===================================================================
; НАСТРОЙКА ТАЙМЕРА 0           ; 16 mks/ed
	ldi     wreg,$3
	out     TCCR0,wreg
;===================================================================
	rcall   sound1
	rcall   sound2
	rcall   sound3
	rcall   z2s
	rcall   sound3
	rcall   sound2
	rcall   sound1
	rcall   sound1
	rcall   sound1
; РАЗ И НАВСЕГДА
	clr     XH             ; сброс старших байтов косвенной адресации
	clr     YH
;===================================================================
; настройка тайmера (стоп часов)
; НЕ НАСТРАИВАЕМ
	clr     fadr1
	clr     fdata
	rcall   wbt
;===================================================================
	clr     fl                       ; сброс собственных флагов
;*********************************************************************
; ИССЛЕДУЕМ ПАМЯТЬ  по первому байту восьмибайтовой ячейки
;    Если ячейка пустая - останавливаем на ней ячейки sob и tsob
	clr     fadr1
	clr     fadr2
cikl_opr_ram:
	rcall   rrar                     ; читаем первый байт события
	ldi     wreg,$FF
	and     fdata,wreg
	breq    opr_sob                  ; определяем пустое событие
; если событие не пустое - переходим к следующему
	ldi     wreg,8
	add     fadr1,wreg
	clr     wreg
	adc     fadr2,wreg
	sbrs    fadr2,5
	rjmp    cikl_opr_ram
; ПЕРЕПОЛНЕНИЕ - тройной сигнал и насильная установка 00 события
	rcall   sound3
	rcall   z01s
	rcall   sound3
	rcall   z01s
	rcall   sound3
	clr     fadr1
	clr     fadr2
opr_sob:
; 3 раза сдвигаем 2 регистра вправо
	lsr     fadr2
	ror     fadr1
	lsr     fadr2
	ror     fadr1
	lsr     fadr2
	ror     fadr1
	sts     sob1,fadr1
	sts     tsob1,fadr1
	sts     sob2,fadr2
	sts     tsob2,fadr2
;*********************************************************************
; По включению определяем конфигурацию:
;*********************************************************************
config:
; обнуляем
	clr     wreg
	sts     sostturn,wreg
	sts     sostfin1,wreg
	sts     sostfin2,wreg
	sts     sostpult,wreg
	sts     sostpist,wreg
	sts     sosttab,wreg
;================================================================
; опрашиваем состояния турникетов
	ldi     wreg,1        ; адрес первого турникета
	mov     rc2,wreg
cikl_opr_turn:
	rcall   z1ms
	clr     word
	rcall   opros1        ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    no_turn
;---------------------------------------------------------------
y_turn:                      ; устройство есть - смотрим какое
; смотрим а не прислал ли нам турникет событие 1
	sbrs	rs232,0
	rjmp	y1_turn
;---------------------------
; прописываем событие 1
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$01               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
;---------------------------------------------------------
y1_turn:
;  заполняем ячейку sostturn
	ldi     wreg,1
	cp      rc2,wreg
	brne    y_turn2
; первый турникет
	sbr     word,$01
	sbrc    rs232,1
	sbr     word,$10
	lds     wreg,sostturn
	or      wreg,word
	sts     sostturn,wreg
	rjmp    no_turn
;---------------------------------------------------------
y_turn2:
	ldi     wreg,2
	cp      rc2,wreg
	brne    y_turn3
; второй турникет
	sbr     word,$02
	sbrc    rs232,1
	sbr     word,$20
	lds     wreg,sostturn
	or      wreg,word
	sts     sostturn,wreg
	rjmp    no_turn
;---------------------------------------------------------
y_turn3:
	ldi     wreg,3
	cp      rc2,wreg
	brne    y_turn4
; третий турникет
	sbr     word,$04
	sbrc    rs232,1
	sbr     word,$40
	lds     wreg,sostturn
	or      wreg,word
	sts     sostturn,wreg
	rjmp    no_turn
;---------------------------------------------------------
y_turn4:
	ldi     wreg,4
	cp      rc2,wreg
	brne    no_turn
; четвертый турникет
	sbr     word,$08
	sbrc    rs232,1
	sbr     word,$80
	lds     wreg,sostturn
	or      wreg,word
	sts     sostturn,wreg
;---------------------------------------------------------------
no_turn:                     ; устройства нет
	inc     rc2
	ldi     wreg,5
	cp      rc2,wreg
	breq    opr_fin
	rjmp    cikl_opr_turn
;===============================================================
;===========ОПРОС ФОТОФИНИШЕЙ===================================
;===============================================================
opr_fin:
	ldi     wreg,5       ; адрес первого фотофиниша
	mov     rc2,wreg
cikl_opr_fin:
	rcall   z1ms
	clr     word         ; ФИНИШИ
	clr     arif1        ; НАСТРОЙКИ
	clr     arif2        ; ПУЛЬТЫ
	rcall   opros1       ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    no_fin
;---------------------------------------------------------------
y_fin:                       ; устройство есть - смотрим какое
; смотрим а не прислал ли нам финиш событие 1
	sbrs	rs232,0
	rjmp	y1_fin
;=====================================================================
	sbrc	rs232,7      ; ПРИЗНАК НОВОГО ФОТОФИНИША
	rjmp	y1_fin       ; если финиш с пультом - потом прочитаем
;---------------------------------------------------------------------
; прописываем событие 1, если фотофиниш без пульта
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$01               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
;=====================================================================
y1_fin:
; заполняем ячейку sostfin1 & sostfin2
	ldi     wreg,5
	cp      rc2,wreg
	brne    y_fin2
; первый финиш
	sbr     word,$01
	sbrc    rs232,1
	sbr     word,$10
	lds     wreg,sostfin1
	or      wreg,word
	sts     sostfin1,wreg

        sbrc    rs232,2
	sbr     arif1,$01
	lds     wreg,sostfin2
	or      wreg,arif1
	sts     sostfin2,wreg

	sbrc    rs232,7
	sbr     arif2,$01
	lds     wreg,sostpult
	or      wreg,arif2
	sts     sostpult,wreg

	rjmp    no_fin
;---------------------------------------------------------------
y_fin2:
	ldi     wreg,6
	cp      rc2,wreg
	brne    y_fin3
; второй финиш
	sbr     word,$02
	sbrc    rs232,1
	sbr     word,$20
	lds     wreg,sostfin1
	or      wreg,word
	sts     sostfin1,wreg

        sbrc    rs232,2
	sbr     arif1,$02
	lds     wreg,sostfin2
	or      wreg,arif1
	sts     sostfin2,wreg

	sbrc    rs232,7
	sbr     arif2,$02
	lds     wreg,sostpult
	or      wreg,arif2
	sts     sostpult,wreg

	rjmp    no_fin
;---------------------------------------------------------------
y_fin3:
	ldi     wreg,7
	cp      rc2,wreg
	brne    y_fin4
; третий финиш
	sbr     word,$04
	sbrc    rs232,1
	sbr     word,$40
	lds     wreg,sostfin1
	or      wreg,word
	sts     sostfin1,wreg

        sbrc    rs232,2
	sbr     arif1,$04
	lds     wreg,sostfin2
	or      wreg,arif1
	sts     sostfin2,wreg

	sbrc    rs232,7
	sbr     arif2,$04
	lds     wreg,sostpult
	or      wreg,arif2
	sts     sostpult,wreg

	rjmp    no_fin
;---------------------------------------------------------------
y_fin4:
	ldi     wreg,8
	cp      rc2,wreg
	brne    no_fin
; четвертый финиш
	sbr     word,$08
	sbrc    rs232,1
	sbr     word,$80
	lds     wreg,sostfin1
	or      wreg,word
	sts     sostfin1,wreg

        sbrc    rs232,2
	sbr     arif1,$08
	lds     wreg,sostfin2
	or      wreg,arif1
	sts     sostfin2,wreg

	sbrc    rs232,7
	sbr     arif2,$08
	lds     wreg,sostpult
	or      wreg,arif2
	sts     sostpult,wreg
;---------------------------------------------------------------
no_fin:                     ; устройства нет
	inc     rc2
	ldi     wreg,9
	cp      rc2,wreg
	breq    opr_tab
	rjmp    cikl_opr_fin
;===============================================================
;=============== ТОБЛЫ =========================================
;===============================================================
opr_tab:
	rcall   z1ms
	ldi     wreg,$10       ; адрес табло
	mov     rc2,wreg
	clr     word
	rcall   opros1         ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    opr_tab_sim

	andi	rs232,$3F      ; две старшие позиции - остаются пустыми

	sbr     word,$01
	or      word,rs232
	sts     sosttab,word
;===============================================================
opr_tab_sim:
	rcall   z1ms
	ldi     wreg,$14       ; адрес табло символьного
	mov     rc2,wreg
;	clr     word           ; ДОПОЛНЯЕМ СЛОВА
	rcall   opros1         ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    end_config

	andi	rs232,$CF      ; две средние позиции - остаются пустыми

	sbr     word,$01       ; контроль питания там будет на своем месте.
	or      word,rs232     ; добавятся две старшие позиции
	sts     sosttab,word
;=======================================================================
; CO СТАРТОВЫМ ПИСТОЛЕТОМ НЕ РАБОТАЕМ
;=======================================================================
end_config:
; смотрим запрос конфигурации или определение ее по включению ( перегрузке)
	sbrs    fl,ZAPCONF
	rjmp    cikl         ; если по включению - уходим в цикл
; если по запросу - отвечаем
	clr     crc
	ldi     wreg,$F5

	add     crc,wreg
	rcall   outbyte          ; "ПОНЯЛ"

	lds     wreg,sostturn
	add     crc,wreg
	rcall   outbyte          ; состояние турникетов

	lds     wreg,sostfin1
	add     crc,wreg
	rcall   outbyte          ; состояние фотофинишей

	lds     wreg,sostfin2
	add     crc,wreg
	rcall   outbyte          ; настройка фотофинишей

	lds     wreg,sostpult
	add     crc,wreg
	rcall   outbyte          ; состояние пультов

	lds     wreg,sosttab
	add     crc,wreg
	rcall   outbyte          ; состояние табло

	lds     wreg,sostpist

	cbr	wreg,$80
	sbis	PIND,3
	sbr	wreg,$80

	add     crc,wreg
	rcall   outbyte          ; состояние стартового пистоля

	clr     wreg
	sub     wreg,crc
	rcall   outbyte          ; контрольная сумма

	cbr     fl,$08
	rcall   z10ms
	rjmp    cikl
;**********************************************************************
;**** ОСНОВНОЙ ЦИКЛ ***************************************************
;**********************************************************************
cikl:
	rcall   z1ms
; ПРОИЗВОДИМ ОПРОС 1 РАЗ В 10 мс примерно через 2 мс на устройство
; запрос с 9 битом = 0; данные и ответ - c 9 битом = 1
   ; СОБЫТИЯ - 01 - сработка для каждого своя
   ;         - 02 - слабое питание
   ;         - 04 - отсутствие настройки для фотофиниша
   ;         - 08 - потеря связи с устройством
; 1. ОПРОС ТУРНИКЕТОВ
	ldi     wreg,1       ; адрес первого турникета
	mov     rc2,wreg
cikl_opros_turn:
;------------------------------------------------------------------------
; смотрим, присутствует ли устройство 1 в соответствующем бите "sostturn"
	mov     arif1,rc2
	lds     arif2,sostturn
; для первого устройства - младший бит =1 - устройство есть
c_o_turn:
	dec     arif1
	breq    mlbit_turn
	lsr     arif2
	rjmp    c_o_turn
;------------------------------------------
; смотрим наличие:
mlbit_turn:
	sbrs    arif2,0
	rjmp    nxt1_turn
;------------------------------------------------------------------------
; если устройство присутствует
	rcall   opros1                 ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    no_conn_turn           ; прописать "нет связи"
	mov     word,rs232
bit1_turn:
	sbrs    word,0
	rjmp    bit2_turn
; прописываем событие 1
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$01               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
;===================================================================
bit2_turn:
	sbrs    word,1
	rjmp    nxt_turn
;-----------------------------------------------------------
; нужно смотреть а уже ли слабое питание  и  если уже - не писать
	mov     arif1,rc2
	lds     arif2,sostturn
	swap    arif2
c1_o_turn:
	dec     arif1
	breq    pow_turn
	ror     arif2
	rjmp    c1_o_turn
;------------------------------------------
; смотрим cлабое питание:
pow_turn:
	sbrc    arif2,0
	rjmp    nxt_turn           ; это если было - не пишем
;------------------------------------------
; если не было слабого питания - изменяем sostturn
	sbr     arif2,$01
	mov     arif1,rc2
c2_o_turn:
	dec     arif1
	breq    pow1_turn
	rol     arif2
	rjmp    c2_o_turn
;-----------------------------------------------------------
pow1_turn:
	swap    arif2
	sts     sostturn,arif2
;-----------------------------------------------------------
; прописываем событие 2
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$02               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; запись события
	rjmp    nxt_turn
;==================================================================
no_conn_turn:
	rjmp    nxt_turn
;==================================================================
nxt_turn:
	rcall   z1ms
nxt1_turn:
	inc     rc2
	ldi     wreg,5
	cp      rc2,wreg
	breq    opros_fin
	rjmp    cikl_opros_turn
;===============================================================
; 2. ОПРОС ФИНИШЕЙ
;===============================================================
opros_fin:
	ldi     wreg,5         ; адрес первого финиша
	mov     rc2,wreg
cikl_opros_fin:
; ЕСЛИ НЕТ ФОТОФИНИША, ТО И ПУЛЬТОВ НЕ ИШШЕМ
; смотрим, присутствует ли устройство 1 в соответствующем бите "sostfin1"
	mov     arif1,rc2
	subi    arif1,$04      ; поправка на финиши
	lds     arif2,sostfin1
; для первого устройства - младший бит =1 - устройство есть
c_o_fin:
	dec     arif1
	breq    mlbit_fin
	lsr     arif2
	rjmp    c_o_fin
;------------------------------------------
mlbit_fin:
; смотрим наличие:
	sbrs    arif2,0
	rjmp    nxt1_fin
;------------------------------------------
; если устройство присутствует
	rcall   opros1        ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    no_conn_fin   ; прописать "нет связи"

	mov     word,rs232
bit1_fin:
	sbrs    word,0
	rjmp    bit2_fin
;--------------------------------------------
; если пришла сработка заведомо сбрасываем состояние "ненастроено"
	mov     arif1,rc2
	subi    arif1,4
	lds     arif2,sostfin2
c5_o_fin:
	dec     arif1
	breq    no_luch_fin
	ror     arif2
	rjmp    c5_o_fin
;------------------------------------------
no_luch_fin:
	cbr     arif2,$01     ; сбрасываем состояние "ненастроено"

	mov     arif1,rc2
	subi    arif1,4
c6_o_fin:
	dec     arif1
	breq    no_luch1_fin
	rol     arif2
	rjmp    c6_o_fin
;-----------------------------------------------------------
no_luch1_fin:
	sts     sostfin2,arif2
;===========================================================
; глядим А КАКОЙ У НАС ФИНИШ
	sbrs    word,7
	rjmp	prop1_fin
;-----------------------------------------------------------
; А ФИНИШ У НАС С ВИНТОМ (т.е. с чипами)
	sts     reg1,rc2               ; устройство
;-----------------------------------------------------------
; готовим куда складывать ( уже готово в системе "ЧИПП")
	clr	ZH
	ldi	ZL,reg2
; ПОСЫЛАЕМ КОМАНДУ
	sbi    PORTB,2                   ; ADM485 на выход
	cbr    fl,$02
	mov    rs232,rc2                 ; команда "передать байты номера"
	sbr    rs232,$40
	rcall  outrs
	sbr    fl,$02
	cbi    PORTB,2                   ; ADM485 на вход
;-------------------------------------------------------------------
; ожидаем ответа на запрос :  5 мс
og_in90:
	ldi    wreg,20
	mov    rz4,wreg
og_in91:
	ldi    wreg,250
	mov    rz3,wreg
og_in92:
	sbis   PINB,0
	rjmp   y_in9
	dec    rz3
	brne   og_in92
	dec    rz4
	brne   og_in91
; не дождались -
	rjmp   bit2_fin      ; не приняли 2 байта - выходим, плохо
; дождались -
;-----------------------------------
y_in9:
	rcall  inrs                ; приняли нормальный ответ
	sbrc   fl,ERRCOM
	rjmp   bit2_fin

	st     Z+,rs232
	cpi    ZL,reg4
	breq   zap_chip
	rjmp   og_in90
; дописываем
zap_chip:
; сдвигаем 4 раза - уносим номер в 3 старшие тетрады
	lds	ZL,reg3
	lds	ZH,reg2
	lsl	ZL
	rol	ZH	
	lsl	ZL
	rol	ZH	
	lsl	ZL
	rol	ZH	
	lsl	ZL
	rol	ZH	
	sbr	ZL,$01		       ; событие	
	sts	reg3,ZL
	sts	reg2,ZH

	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
	rjmp	nxt_fin                ; питание в другой раз
;======================================================================
; ПРОСТО ФИНИШ
prop1_fin:
; прописываем событие 1
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$01               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
	rjmp	nxt_fin
;======================================================================
bit2_fin:
	sbrs    word,1
	rjmp    bit3_fin
; нужно смотреть а уже ли слабое питание  и  если уже - не писать
	mov     arif1,rc2
	subi    arif1,4
	lds     arif2,sostfin1
	swap    arif2
c1_o_fin:
	dec     arif1
	breq    pow_fin
	ror     arif2
	rjmp    c1_o_fin
; смотрим cлабое питание:
pow_fin:
	sbrc    arif2,0
	rjmp    bit3_fin           ; это если было - не пишем
; если не было слабого питания - изменяем sostfin
	sbr     arif2,$01
	mov     arif1,rc2
	subi	arif1,4
c2_o_fin:
	dec     arif1
	breq    pow1_fin
	rol     arif2
	rjmp    c2_o_fin
;-----------------------------------------------------------
pow1_fin:
	swap    arif2
	sts     sostfin1,arif2
; прописываем событие 2
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$02               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
;------------------------------------------------------------------
bit3_fin:
	sbrs    word,2
	rjmp    nxt_fin
 нужно смотреть а уже ли потеря луча  и  если уже - не писать
	mov     arif1,rc2
	subi    arif1,4
	lds     arif2,sostfin2
c3_o_fin:
	dec     arif1
	breq    luch_fin
	ror     arif2
	rjmp    c3_o_fin
;------------------------------------------
; смотрим :
luch_fin:
	sbrc    arif2,0
	rjmp    nxt_fin           ; это если было - не пишем
;------------------------------------------
; если не было слабого питания - изменяем sostturn
	sbr     arif2,$01
	mov     arif1,rc2
	dec     arif1             ; без переноса
	dec     arif1
	dec     arif1
	dec     arif1
c4_o_fin:
	dec     arif1
	breq    luch1_fin
	rol     arif2
	rjmp    c4_o_fin
;-----------------------------------------------------------
luch1_fin:
	sts     sostfin2,arif2
; прописываем событие 3
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$04               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
	rjmp    nxt_fin
;------------------------------------------------------------------
no_conn_fin:
	rjmp    nxt_fin
;------------------------------------------------------------------
nxt_fin:
	rcall   z1ms
nxt1_fin:
	inc     rc2
	ldi     wreg,9
	cp      rc2,wreg
	breq    opros_tab
	rjmp    cikl_opros_fin
;===============================================================
; 2. ОПРОС ТАБЛО
opros_tab:
	rcall	z1ms
	ldi     wreg,$10       ; адрес табло
	mov     rc2,wreg
	lds     wreg,sosttab
	sbrs    wreg,0
	rjmp    cikl1
	andi	wreg,$30       ; есть ли символьные строки
	brne	opros_tab1
	rjmp	opros_stab
;---------------------------------------------------------
opros_tab1:
	rcall   opros1         ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    no_conn_tab    ; прописать "нет связи"
	mov     word,rs232
;----------------------------------------------------------------
	sbrs    word,1
	rjmp    opros_stab          ; выход из опроса
; нужно смотреть а уже ли слабое питание  и  если уже - не писать
	lds     arif2,sosttab
	sbrc    arif2,1
	rjmp    opros_stab          ; это если было - не пишем
;------------------------------------------
; если не было слабого питания - изменяем sosttab
	sbr     arif2,$02
	sts     sosttab,arif2
; прописываем событие 2
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$02               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
;------------------------------------------------------------------
no_conn_tab:
	rjmp    opros_stab
;********************************************************************
;********************************************************************
;  ОПРОС ТАБЛО СИМВОЛЬНОГО
opros_stab:
	ldi     wreg,$14       ; адрес табло
	mov     rc2,wreg
	lds     wreg,sosttab
	sbrs    wreg,0
	rjmp    cikl1
	andi	wreg,$C0       ; есть ли символьные строки
	brne	opros_stab1
	rjmp	cikl1
;--------------------------------------------------------------------
opros_stab1:
	rcall	z1ms
	rcall   opros1         ; подпрограмма двойного опроса одного устройства
; результатом является регистр rs232 и флаг недожидания ответа ERRCOM
	sbrc    fl,ERRCOM
	rjmp    no_conn_stab    ; прописать "нет связи"
	mov     word,rs232
;----------------------------------------------------------------
	sbrs    word,2
	rjmp    cikl1           ; выход из опроса
; нужно смотреть а уже ли слабое питание  и  если уже - не писать
	lds     arif2,sosttab
	sbrc    arif2,2
	rjmp    cikl1           ; это если было - не пишем
;------------------------------------------
; если не было слабого питания - изменяем sosttab
	sbr     arif2,$04
	sts     sosttab,arif2
; прописываем событие 2
	sts     reg1,rc2               ; устройство
	ldi     wreg,$00               ; событие
	sts     reg2,wreg
	ldi     wreg,$02               ; событие
	sts     reg3,wreg
	rcall   time_in_reg
	rcall   sobwrite               ; переход на запись события
;------------------------------------------------------------------
no_conn_stab:
	rjmp    cikl1
;********************************************************************
;********************************************************************
; проверяем приход запроса с COM-PORTA и уходим снова в опрос
cikl1:
; в случае отрицательного времени опрашиваем еще и секунду
	ldi     wreg,4
	mov     fadr1,wreg
	rcall   rrat
	sbrs    fdata,7
	rjmp    cikl2
;-------------------------------
	in      wreg,GIFR
	sbrs    wreg,6
	rjmp    cikl2               ;
;-----------------------------------------------------------------------
	ldi     wreg,$C0            ; чистим флаг
	out     GIFR,wreg
	rcall   time_in_reg
cikl2:
	rcall   z10ms             ; 5 мс - резерв
; опрашиваем UART
;       РАБОТА С UART             - в соответствии с файлом PROTOKOL
	sbic    USR,RXC
	rjmp    comport
	rjmp    cikl
;************************************************************************
; ОБРАБОТКА КОМПЬЮТЕРНЫХ ЗАПРОСОВ
;************************************************************************
comport:
	in      wreg,UDR          ; переносит данные, чистит флаг
	cpi     wreg,0            ; сравнение с командой "ЗАПРОС СВЯЗИ"
	breq    otv00
	rjmp    otvERR            ; если не запрос связи - ответить ошибкой
;-----------------------------------------------------------
; ответ на запрос связи
otv00:  rcall   z1ms
	ldi     wreg,$F5
	rcall   outbyte
;-----------------------------------------------------------
; ожидаем 50 мс прихода дальнейшей информации
	ldi     wreg,200
	mov     rz2,wreg
ogin1:
	rcall   z250
	sbic    USR,RXC
	rjmp    an_kom           ; переход на прием команды
	dec     rz2
	brne    ogin1
; не дождались - большой привет
	rjmp    cikl1
;=======================================================================
; принимаем команду
an_kom:
	in      wreg,UDR
	sts     regcom1,wreg   ; сохраняем команду для возможной передачи
; АНАЛИЗИРУЕМ КОМАНДУ
;***********************************************************************
;***********************************************************************
;        КОМАНДЫ, ОБРАЩЕННЫЕ К СИСТЕМНОМУ ТАЙМЕРУ
; 1             20h - доложить состояние системы
; 2             40h - передать текущее событие
; 3             60h - очистить память
; 4             80h - запуск часов
; 5             A0h - начать с первого события
; 6             0Fh - перегузка системы
; 7             4xh - задать настройки турникета
; 8             6xh - задать строку протокола
; 9             5xh - послать строку в табло ( 12 символов)
;***********************************************************************
;***********************************************************************
	cpi     wreg,$20         ;
	brne    ankom1
	rjmp    dol_sost
ankom1:
	cpi     wreg,$40         ;
	brne    ankom2
	rjmp    tek_sob
ankom2:
	cpi     wreg,$60         ;
	brne    ankom3
	rjmp    resetF
ankom3:
	cpi     wreg,$80         ;
	brne    ankom4
        rjmp    ust_time
ankom4:
	cpi     wreg,$A0
	brne    ankom5
        rjmp    first
ankom5:
	cpi     wreg,$0F
	brne    ankom6
        rjmp    peregruz
ankom6:
	andi    wreg,$F0
	cpi     wreg,$40
	brne    ankom7
        rjmp    nastr
ankom7:
	andi    wreg,$F0
	cpi     wreg,$60
	brne    ankom8
        rjmp    stroka
ankom8:
	andi    wreg,$F0
	cpi     wreg,$50
	brne    ankom9
        rjmp    strok_tab
ankom9:
	andi    wreg,$F0
	cpi     wreg,$70
	brne    otvERR
        rjmp    strok_stab
;************************************************************************
;********************* ОТВЕТ С ОШИБКОЙ **********************************
;************************************************************************
otvERR:
	rcall   z250
	ldi     wreg,$F6
	rcall   outbyte
	rjmp    cikl
;************************************************************************
;********************* ОТВЕТ БЕЗ ОШИБКИ *********************************
;************************************************************************
otvOK:
	rcall   z250
	ldi     wreg,$F5
	rcall   outbyte
	rjmp    cikl
;************************************************************************
;********************* ОТВЕТ ПРО ЗАПУЩЕННОЕ ВРЕМЯ ***********************
;************************************************************************
otvTZ:
	rcall   z250
	ldi     wreg,$F4
	rcall   outbyte
	rjmp    cikl
;************************************************************************
;********************* ОЧИСТКА ПАМЯТИ ***********************************
;************************************************************************
resetF:
	rcall   z1ms
	ldi     wreg,$F5
	rcall   outbyte
;  1 - обнуляем страницу
        ldi	YL,reg1
	clr     wreg
zero32:	st      Y+,wreg
	cpi     YL,reg33
	brne    zero32
;-------------------------------------------------------------------
; обнулили страницу - начинаем грузить память  c 20 адреса
	clr     fadr1
	clr     fadr2
zero8k:
	sbr     fl,$01               ; флаг длинной страницы
;-----------------------------------------------------------------
	rcall   wpr                  ; запись страницы
	rcall   z10ms
	ldi     wreg,$20
	add     fadr1,wreg
	clr     wreg
	adc     fadr2,wreg
	sbrs    fadr2,5              ; если более 8k
	rjmp    zero8k
;-----------------------------------------------------------
	cbr     fl,$01               ; флаг длинной страницы
;-------------------------------------------------------------------
	rcall   sound1
	ldi     wreg,$00
	sts     sob2,wreg            ; установка счетчика событий
	sts     tsob2,wreg
	sts     sob1,wreg
	sts     tsob1,wreg
	rjmp    cikl
;************************************************************************
;    ДОЛОЖИТЬ СОСТОЯНИЕ
;************************************************************************
dol_sost:                            ;
	sbr      fl,$08
	rjmp     config
;***********************************************************************
;********************* ПЕРЕДАТЬ ТЕКУЩЕЕ СОБЫТИЕ ************************
;***********************************************************************
tek_sob:
	rcall   z250
; определяем, есть ли текущее событие
	lds     wreg,tsob1
	lds     bufer,sob1
	cp      wreg,bufer
	brne    out_tek_sob
;-------------------------------------
	lds     wreg,tsob2
	lds     bufer,sob2
	cp      wreg,bufer
	brne    out_tek_sob
;=================================================================
; иначе отвечаем F7 + время + kc
	clr     crc

	ldi     wreg,$F7
	add     crc,wreg
	rcall   outbyte          ; "ПОНЯЛ"

	ldi     wreg,$00
	rcall   outbyte          ;

	ldi     wreg,$00
	rcall   outbyte          ;

	ldi     wreg,$00
	rcall   outbyte          ;

	rcall   time_in_reg

	lds     wreg,reg4
	add     crc,wreg
	rcall   outbyte          ; "ЧАСЫ"

	lds     wreg,reg5
	add     crc,wreg
	rcall   outbyte          ; "МИНУТЫ"

	lds     wreg,reg6
	add     crc,wreg
	rcall   outbyte          ; "СЕКУНДЫ"

	lds     wreg,reg7
	add     crc,wreg
	rcall   outbyte          ; "ДЕСЯТЫЕ"

	clr     wreg
	sub     wreg,crc
	rcall   outbyte          ; контрольная сумма

	rjmp    cikl
;=================================================================
out_tek_sob:
	clr     crc

	ldi     wreg,$F5
	add     crc,wreg
	rcall   outbyte          ; "ПОНЯЛ"

	rcall   opr_adr1
	rcall   rrar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	rcall   rcar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	rcall   rcar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	rcall   rcar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	rcall   rcar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	rcall   rcar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	rcall   rcar
	mov     wreg,fdata
	add     crc,wreg
	rcall   outbyte          ;

	clr     wreg
	sub     wreg,crc
	rcall   outbyte          ;

	lds     wreg,tsob1
	inc     wreg
	sts     tsob1,wreg
	brne    tsobout
	lds     wreg,tsob2
	inc     wreg
	sts     tsob2,wreg
	sbrs    wreg,2
	rjmp    tsobout
	ldi     wreg,0
	sts     tsob1,wreg
	sts     tsob2,wreg
tsobout:
	rcall   sound4
	rjmp    cikl
;***************************************************************
;********************* УСТАНОВИТЬ ВРЕМЯ ************************
;***************************************************************
ust_time:
; принимаем еще 4 байт ЧЧ-ММ-СС-КС
	ldi     YL,regcom2
; ожидаем 5 мс прихода дальнейшей информации
ogin2:
	ldi     wreg,20
	mov     rz2,wreg
ogin21:
	rcall   z250
	sbic    USR,RXC
	rjmp    nxt2           ; переход на прием cледующего
	dec     rz2
	brne    ogin21
; не дождались - большой привет
	rjmp    otvERR
; байт принят
nxt2:   in      wreg,UDR
	st      Y+,wreg
	cpi     YL,regcom6
	brne    ogin2
;=======================================================================
; приняли все 4 байт - проверяем контрольную сумму  (regcom1 - regcom5)
	lds     crc,regcom1
	lds     wreg,regcom2
	add     crc,wreg
	lds     wreg,regcom3
	add     crc,wreg
	lds     wreg,regcom4
	add     crc,wreg
	lds     wreg,regcom5
	add     crc,wreg
	breq    ust1_time
	rjmp    otvERR
;=======================================================================
ust1_time:
	sbrc     fl,TIMEZ    ; если время запущено - так и отвечаем
	rjmp     otvTZ
; устанавливаем время в турникеты ( какие есть в системе )
	ldi     wreg,1       ; адрес первого турникета
	mov     rc2,wreg
cikl_time_turn:
;------------------------------------------------------------------------
; смотрим, присутствует ли устройство 1 в соответствующем бите "sostturn"
	mov     arif1,rc2
	lds     arif2,sostturn
; для первого устройства - младший бит =1 - устройство есть
c_t_turn:
	dec     arif1
	breq    mlb_turn
	lsr     arif2
	rjmp    c_t_turn
;------------------------------------------
; смотрим наличие:
mlb_turn:
	sbrs    arif2,0
	rjmp    nxt1_time_turn
;------------------------------------------------------------------------
; если устройство присутствует
	cbr     fl,$02
	sbi     PORTB,2                   ; ADM485 на выход
	clr     crc

	lds     rs232,regcom1             ; -КОМАНДА
	or      rs232,rc2
	add     crc,rs232
	rcall   outrs

	sbr     fl,$02

	lds     rs232,regcom2             ;-ЧАСЫ
	add     crc,rs232
	rcall   outrs
	rcall   z100
	lds     rs232,regcom3             ;-МИНУТЫ
	add     crc,rs232
	rcall   outrs
	rcall   z100
	lds     rs232,regcom4             ;-СЕКУНДЫ
	add     crc,rs232
	rcall   outrs
	rcall   z100
; вычисляем контрольную сумму
	clr     rs232
	sub     rs232,crc
	rcall   outrs           ; контрольная сумма

	cbi     PORTB,2                   ; ADM на ВХОД
; ожидаем ответа на установку времени :  20 мс
og_in4:
	ldi     wreg,80
	mov     rz4,wreg
og_in41:
	ldi     wreg,250
	mov     rz3,wreg
og_in42:
	sbis    PINB,0
	rjmp    y_in4
	dec     rz3
	brne    og_in42
	dec     rz4
	brne    og_in41
; не дождались -
	rcall   sound3
	rjmp    nxt_time_turn
; дождались -
y_in4:
	rcall   inrs
	rjmp    nxt_time_turn
;------------------------------------------------------------
nxt_time_turn:
	rcall   z10ms
nxt1_time_turn:
	inc     rc2
	ldi     wreg,5
	cp      wreg,rc2
	breq    ust2_time
	rjmp    cikl_time_turn
;====================================================================
ust2_time:
; устанавливаем время в самом системном таймере
	lds     wreg,regcom2
	sbrs    wreg,7
	rjmp    ust3_time           ; положительное время просто устанавливаем в таймер
;--------------------------------------------------------------------
; в случае отрицательного времени дополнительно грузим его в "предстарт"
; а в таймере время обнуляем
	lds     wreg,regcom2
	andi    wreg,$0F
	sts     psth,wreg
	lds     wreg,regcom3
	andi    wreg,$0F
	sts     pstm2,wreg
	lds     wreg,regcom3
	swap    wreg
	andi    wreg,$0F
	sts     pstm1,wreg
	lds     wreg,regcom4
	andi    wreg,$0F
	sts     psts2,wreg
	lds     wreg,regcom4
	swap    wreg
	andi    wreg,$0F
	sts     psts1,wreg

	clr     fadr1
	clr     fdata
	rcall   wbt
	ldi     wreg,1
	mov     fadr1,wreg       ; десятые
	clr     fdata
	rcall   wbt
	inc     fadr1            ; секунды
	rcall   wbt
	inc     fadr1            ; минуты
	rcall   wbt
	inc     fadr1            ; часы
	ldi     wreg,$80
	mov     fdata,wreg
	rcall   wbt

	sbr     fl,$10           ; часы запущены
	rjmp    otvOK
;--------------------------------------------------------------------
ust3_time:
	clr     fadr1
	clr     fdata
	rcall   wbt
	ldi     wreg,1
	mov     fadr1,wreg       ; десятые
	clr     fdata
	rcall   wbt
	inc     fadr1            ; секунды
	lds     fdata,regcom4
	rcall   wbt
	inc     fadr1            ; минуты
	lds     fdata,regcom3
	rcall   wbt
	inc     fadr1            ; часы
	lds     fdata,regcom2
	rcall   wbt

	sbr     fl,$10           ; часы запущены
	rjmp    otvOK
;***********************************************************************
;****** НАЧАТЬ СНАЧАЛА *************************************************
;***********************************************************************
first:  ldi     wreg,0
	sts     tsob1,wreg
	sts     tsob2,wreg
	rjmp    otvOK
;***********************************************************************
;*******ПЕРЕГРУЗКА******************************************************
;***********************************************************************
peregruz:
; посылаем "ПЕРЕГРУЗКУ" В МАГИСТРАЛЬ ПОСЛЕ ЧЕГО ПЕРЕГРУЖАЕМСЯ САМИ
	sbi    PORTB,2                   ; ADM485 на выход
	cbr    fl,$02
	ldi    rs232,$0F  ;  - СБРОС
	rcall  outrs
	cbi    PORTB,2                   ; ADM485 на вход
; отвечаем что понял и перегружаемся
	rcall   z1ms
	ldi     wreg,$F5
	rcall   outbyte
	rcall   z1ms
	rjmp    RESET
;***********************************************************************
;******ЗАДАТЬ НАСТРОЙКИ ТУРНИКЕТА***************************************
;***********************************************************************
nastr:
; принимаем еще 6 байт ИНТМИН-ИНТСЕК-ННОМ1-ННОМ2-СТАРТ-КС
	ldi     YL,regcom2
; ожидаем 5 мс прихода дальнейшей информации
ogin3:
	ldi     wreg,20
	mov     rz2,wreg
ogin31:
	rcall   z250
	sbic    USR,RXC
	rjmp    nxt3           ; переход на прием cледующего
	dec     rz2
	brne    ogin31
; не дождались - большой привет
	rjmp    otvERR
; байт принят
nxt3:   in      wreg,UDR
	st      Y+,wreg
	cpi     YL,regcom8
	brne    ogin3
;=======================================================================
; приняли все 6 байт - проверяем контрольную сумму  (regcom1 - regcom5)
	lds     crc,regcom1
	lds     wreg,regcom2
	add     crc,wreg
	lds     wreg,regcom3
	add     crc,wreg
	lds     wreg,regcom4
	add     crc,wreg
	lds     wreg,regcom5
	add     crc,wreg
	lds     wreg,regcom6
	add     crc,wreg
	lds     wreg,regcom7
	add     crc,wreg
	breq    nastr1
	rjmp    otvERR
;=======================================================================
nastr1:
	sbrc    fl,TIMEZ    ; если время запущено - так и отвечаем
	rjmp    otvTZ

	sbi    PORTB,2                   ; ADM485 на выход
	cbr    fl,$02
	clr    crc
	lds    rs232,regcom1             ;  -КОМАНДА  "НАСТРОЙКИ"
	add    crc,rs232
	rcall  outrs

	sbr    fl,$02
	lds    rs232,regcom2             ;  - МИНУТЫ ИНТЕРВАЛА
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom3             ;  - СЕКУНДЫ ИНТЕРВАЛА
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom4             ;  - НАЧАЛЬНЫЙ НОМЕР СТ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom5             ;  - НАЧАЛЬНЫЙ НОМЕР МЛ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom6             ; - ШАГ
	add    crc,rs232
	rcall  outrs
; вычисляем контрольную сумму
	clr    rs232
	sub    rs232,crc
	rcall  outrs           ; контрольная сумма

	cbi    PORTB,2                   ; ADM485 на вход
;-----------------------------------------------------------------------
; ожидаем ответа на настройки :  20 мс
og_in3:
	ldi    wreg,80
	mov    rz4,wreg
og_in31:
	ldi    wreg,250
	mov    rz3,wreg
og_in32:
	nop
	nop
	nop
	nop
	sbis   PINB,0
	rjmp   y_in3
	dec    rz3
	brne   og_in32
	dec    rz4
	brne   og_in31
; не дождались -
	rjmp   otvERR
; дождались -
y_in3:
	rcall  inrs
	sbrc   fl,ERRCOM
	rjmp   otvERR
	cpi    rs232,0
	breq   gotoOK3
	rjmp   otvERR
;------------------------------------------------------------
gotoOK3:
	rjmp   otvOK
;***********************************************************************
;***** ЗАДАТЬ СТРОКУ ПРОТОКОЛА ТУРНИКЕТА *******************************
;***********************************************************************
stroka:
; принимаем еще 6 байт НОМ1-НОМ2-ЧАСЫ-МИНУТЫ-СЕКУНДЫ-КС
	ldi     YL,regcom2
; ожидаем 5 мс прихода дальнейшей информации
ogin5:
	ldi     wreg,20
	mov     rz2,wreg
ogin51:
	rcall   z250
	sbic    USR,RXC
	rjmp    nxt5           ; переход на прием cледующего
	dec     rz2
	brne    ogin51
; не дождались - большой привет
	rjmp    otvERR
; байт принят
nxt5:   in      wreg,UDR
	st      Y+,wreg
	cpi     YL,regcom8
	brne    ogin5
;=======================================================================
; приняли все 6 байт - проверяем контрольную сумму  (regcom1 - regcom7)
	lds     crc,regcom1
	lds     wreg,regcom2
	add     crc,wreg
	lds     wreg,regcom3
	add     crc,wreg
	lds     wreg,regcom4
	add     crc,wreg
	lds     wreg,regcom5
	add     crc,wreg
	lds     wreg,regcom6
	add     crc,wreg
	lds     wreg,regcom7
	add     crc,wreg
	breq    stroka1
	rjmp    otvERR
;=======================================================================
stroka1:
	sbrc    fl,TIMEZ    ; если время запущено - так и отвечаем
	rjmp    otvTZ

	sbi     PORTB,2                   ; ADM485 на выход
	cbr     fl,$02
	clr     crc
	lds     rs232,regcom1             ;  -КОМАНДА  "СТРОКА"
	add     crc,rs232
	rcall   outrs

	sbr     fl,$02
	lds     rs232,regcom2             ;
	add     crc,rs232
	rcall   outrs
	lds     rs232,regcom3             ;
	add     crc,rs232
	rcall   outrs
	lds     rs232,regcom4             ;
	add     crc,rs232
	rcall   outrs
	lds     rs232,regcom5             ;
	add     crc,rs232
	rcall   outrs
	lds     rs232,regcom6             ;
	add     crc,rs232
	rcall   outrs
; вычисляем контрольную сумму
	clr    rs232
	sub    rs232,crc
	rcall  outrs                     ; контрольная сумма

	cbi    PORTB,2                   ; ADM485 на вход
;-----------------------------------------------------------------------
	rjmp   og_in3
;***********************************************************************
;***** ЗАДАТЬ СТРОКУ В ТАБЛО *******************************************
;***********************************************************************
strok_tab:
; принимаем еще 8 байт МЕС1-МЕС2-НОМ1-НОМ2-ЧАСЫ-МИНУТЫ-СЕКУНДЫ-КС
	ldi     YL,regcom2
; ожидаем 5 мс прихода дальнейшей информации
ogin6:
	ldi     wreg,20
	mov     rz2,wreg
ogin61:
	rcall   z250
	sbic    USR,RXC
	rjmp    nxt6           ; переход на прием cледующего
	dec     rz2
	brne    ogin61
; не дождались - большой привет
	rjmp    otvERR
; байт принят
nxt6:   in      wreg,UDR
	st      Y+,wreg
	cpi     YL,regcom10
	brne    ogin6
;=======================================================================
; приняли все 6 байт - проверяем контрольную сумму  (regcom1 - regcom9)
	lds     crc,regcom1
	lds     wreg,regcom2
	add     crc,wreg
	lds     wreg,regcom3
	add     crc,wreg
	lds     wreg,regcom4
	add     crc,wreg
	lds     wreg,regcom5
	add     crc,wreg
	lds     wreg,regcom6
	add     crc,wreg
	lds     wreg,regcom7
	add     crc,wreg
	lds     wreg,regcom8
	add     crc,wreg
	lds     wreg,regcom9
	add     crc,wreg
	breq    strok_tab1
	rjmp    otvERR
;=======================================================================
strok_tab1:
	sbi    PORTB,2                   ; ADM485 на выход
	cbr    fl,$02
	clr    crc
	lds    rs232,regcom1             ;  -КОМАНДА  "СТРОКА"
	add    crc,rs232
	rcall  outrs
	sbr    fl,$02
;---------------------------------------------------------------------
; преобразуем место
	lds    wreg,regcom2
	sts    plH,wreg
	lds    wreg,regcom3
	sts    plL,wreg
	rcall  out_M
; отправляем место
	lds    rs232,pl1             ;
	add    crc,rs232
	rcall  outrs
	lds    rs232,pl2             ;
	add    crc,rs232
	rcall  outrs
	lds    rs232,pl3             ;
	add    crc,rs232
	rcall  outrs
;---------------------------------------------------------------------
; преобразуем номер
	lds    wreg,regcom4
	sts    plH,wreg
	lds    wreg,regcom5
	sts    plL,wreg
	rcall  out_M
; отправляем номер
	lds    rs232,pl1             ;
	add    crc,rs232
	rcall  outrs
	lds    rs232,pl2             ;
	add    crc,rs232
	rcall  outrs
	lds    rs232,pl3             ;
	add    crc,rs232
	rcall  outrs
;---------------------------------------------------------------------
	lds    rs232,regcom6             ; ЧАСЫ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom7             ; МИНУТЫ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom8             ; СЕКУНДЫ
	add    crc,rs232
	rcall  outrs
; вычисляем контрольную сумму
	clr    rs232
	sub    rs232,crc
	rcall  outrs                     ; контрольная сумма

	cbi    PORTB,2                   ; ADM485 на вход
;-----------------------------------------------------------------------
	ldi    wreg,200                  ; 50 мс
	mov    rz4,wreg
	rjmp   og_in31
;***********************************************************************
;***** ЗАДАТЬ СТРОКУ В ТАБЛО *******************************************
;***********************************************************************
strok_stab:
; принимаем еще 11 байт 10 БЕЗ РАЗНИЦЫ КАКИХ И КС
	ldi     YL,regcom2
; ожидаем 5 мс прихода дальнейшей информации
ogin7:
	ldi     wreg,20
	mov     rz2,wreg
ogin71:
	rcall   z250
	sbic    USR,RXC
	rjmp    nxt7           ; переход на прием cледующего
	dec     rz2
	brne    ogin71
; не дождались - большой привет
	rjmp    otvERR
; байт принят
nxt7:   in      wreg,UDR
	st      Y+,wreg
	cpi     YL,regcom13
	brne    ogin7
;=======================================================================
; приняли все 12 байт - проверяем контрольную сумму  (regcom1 - regcom9)
	lds     crc,regcom1
	lds     wreg,regcom2
	add     crc,wreg
	lds     wreg,regcom3
	add     crc,wreg
	lds     wreg,regcom4
	add     crc,wreg
	lds     wreg,regcom5
	add     crc,wreg
	lds     wreg,regcom6
	add     crc,wreg
	lds     wreg,regcom7
	add     crc,wreg
	lds     wreg,regcom8
	add     crc,wreg
	lds     wreg,regcom9
	add     crc,wreg
	lds     wreg,regcom10
	add     crc,wreg
	lds     wreg,regcom11
	add     crc,wreg
	lds     wreg,regcom12
	add     crc,wreg
	breq    strok_stab1
	rjmp    otvERR
;=======================================================================
strok_stab1:
	sbi    PORTB,2                   ; ADM485 на выход
	cbr    fl,$02

	clr    crc
	lds    rs232,regcom1             ; -КОМАНДА  "СТРОКА"
	add    crc,rs232
	rcall  outrs
	sbr    fl,$02
	lds    rs232,regcom2             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom3             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom4             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom5             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom6             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom7             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom8             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom9             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom10             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
	lds    rs232,regcom11             ; -ДАННЫЕ
	add    crc,rs232
	rcall  outrs
;---------------------------------------------------------------------
	clr    rs232
	sub    rs232,crc
	rcall  outrs                     ; контрольная сумма

	cbi    PORTB,2                   ; ADM485 на вход
;-----------------------------------------------------------------------
	ldi    wreg,200                  ; 50 мс
	mov    rz4,wreg
	rjmp   og_in31                   ; ожидаем ответ от устройства

;***********************************************************************
; ПРЕРЫВАНИЕ ОТ ТАЙМЕРА
inv_sound:	
	sbis	PORTB,5
	rjmp	setsound
        cbi	PORTB,5
	rjmp	nxtsound
setsound:
        sbi	PORTB,5
nxtsound:
	ldi	ZH,02
	out	TIFR,ZH

	dec	soun
        brne	prod_sound
;--------------------------------
; прекращаем писк	
	clr	ZH
	out     TCCR0,ZH
	out	TCNT0,ZH
	out	TIMSK,ZH
	cbi	PORTB,5
	cli
	reti		
;--------------------------------
prod_sound:
; заряжаем таймер на 250 мкс
	ldi     ZH,$23                  ; 8 мкс\ дискрет
	out     TCCR0,ZH
 	ldi	ZH,226	
	out	TCNT0,ZH
; разрешаем прерывания по переполнению
 	ldi	ZH,$02	
	out	TIMSK,ZH
	clr	ZH
;        sei
	reti
;-------------------------------------



;***********************************************************************
;*********П О Д П Р О Г Р А М М Ы***************************************
;***********************************************************************
;*******ОПРОС УСТРОЙСТВА************************************************
;***********************************************************************
opros1:
; ПОДПРОГРАММА 3-х кратного опроса устройства нижнего уровня с адресом [rc2]
	cbr    fl,$04
	ldi    wreg,3
	mov    count3,wreg
opros11:
	sbi    PORTB,2                   ; ADM485 на выход
	cbr    fl,$02
	mov    rs232,rc2                 ;
	sbr    rs232,$20
	rcall  outrs
	sbr    fl,$02
	cbi    PORTB,2                   ; ADM485 на вход
;-------------------------------------------------------------------
; ожидаем ответа на запрос :  5 мс
og_in2:
	ldi    wreg,40
	mov    rz4,wreg
og_in21:
	ldi    wreg,250
	mov    rz3,wreg
og_in22:
	sbis   PINB,0
	rjmp   y_in2
	dec    rz3
	brne   og_in22
	dec    rz4
	brne   og_in21
; не дождались -
count3dec:
	rcall  z1ms
	dec    count3
	brne   opros11
	sbr    fl,$04
	ret
; дождались -
y_in2:
	rcall  inrs                ; приняли нормальный ответ - выход
	sbrc   fl,ERRCOM
	rjmp   count3dec
	ret
;************************************************************************
;***********ПОДПРОГРАММЫ ПРЕОБРАЗОВАНИЯ МЕСТА****************************
;************************************************************************
out_M:
; преобразует 2 байта места в 3 байта десятичных разрядов для индикации
	clr     bufer
	lds     wordh,plH
	lds     word,plL
; вычитаем сотню и считаем сколько раз пока не установится перенос
m100_1: sbiw    word,50
	brcs    y100_1              ;  если перенос - сотни кончились
	inc     bufer
	rjmp    m100_1
y100_1: adiw    word,50
	sbrc    bufer,0             ;  если четное число - прибавить 50
	adiw    word,50
; сбрасываем младший разряд и сдвигаем вправо - результат есть старший разряд
	lsr     bufer
	sts     pl1,bufer
;----------------------------------------------------------
	clr     bufer
m10_1:  sbiw    word,10
	brcs    y10_1               ;  если перенос - сотни кончились
	inc     bufer
	rjmp    m10_1
y10_1:  adiw    word,10
	sts     pl2,bufer          ;
	sts     pl3,word
	ret
;***********************************************************************
;*******ЗАПИСЬ СОБЫТИЯ**************************************************
;***********************************************************************
sobwrite:
	rcall   opr_adr                ; определяем адрес свободной ячейки
	rcall   wpr                    ; записываем страницу
	rcall   z10ms
; увеличиваем счетчик событий
	lds     wreg,sob1
	inc     wreg
	sts     sob1,wreg
	brne    sobout
	lds     wreg,sob2
	inc     wreg
	sts     sob2,wreg
	sbrs    wreg,2
	ret
	ldi     wreg,0
	sts     sob1,wreg
	sts     sob2,wreg
sobout:
	ret
;***********************************************************************
;**********ЧТЕНИЕ РЕАЛЬНОГО ВРЕМЕНИ В РЕГИСТРЫ *************************
;***********************************************************************
time_in_reg:
; читаем реальное время
; пропуск
	ldi     wreg,0
	sts     reg8,wreg
; десятые
	ldi     wreg,$01            ;
	mov     fadr1,wreg
	rcall   rrat
	mov     wreg,fdata
	swap    wreg
	sts     reg7,wreg
	sts     rd,wreg
; секунды
	rcall   rcat
	sts     reg6,fdata
	mov     wreg,fdata
	andi    wreg,$0F
	sts     rs2,wreg
	mov     wreg,fdata
	swap    wreg
	andi    wreg,$0F
	sts     rs1,wreg
; минуты
	rcall   rcat
	sts     reg5,fdata
	mov     wreg,fdata
	andi    wreg,$0F
	sts     rm2,wreg
	mov     wreg,fdata
	swap    wreg
	andi    wreg,$0F
	sts     rm1,wreg
; часы
	rcall   rcat
	sts     reg4,fdata
	mov     wreg,fdata
	andi    wreg,$0F
	sts     rh,wreg
;----------------------------------------------------------------------
; если время отрицательное - инвертим относительно предстарта и
; устанавливаем старший бит часов
	sbrs    fdata,7
	ret                    ; если не предстарт - все ОК

	lds     wreg,psth
	sts     th,wreg
	lds     wreg,pstm1
	sts     tm1,wreg
	lds     wreg,pstm2
	sts     tm2,wreg
	lds     wreg,psts1
	sts     ts1,wreg
	lds     wreg,psts2
	sts     ts2,wreg
	lds     wreg,pstd
	sts     td,wreg
;------------------------------------------------
	rcall   t_minus_r
; проверяем t на 0 и если 0 - сбрасываем флаг отрицательного времени в таймере
	lds     wreg,th
	andi    wreg,$FF
	brne    time_ret
	lds     wreg,tm1
	andi    wreg,$FF
	brne    time_ret
	lds     wreg,tm2
	andi    wreg,$FF
	brne    time_ret
	lds     wreg,ts1
	andi    wreg,$FF
	brne    time_ret
	lds     wreg,ts2
	andi    wreg,$FF
	brne    time_ret
;------------------------------------------------------------------
; если 0 - перезапускаем часы с 0 - флаг сбрасываем
	clr     fadr1
	clr     fdata
	rcall   wbt
	ldi     wreg,1
	mov     fadr1,wreg
	clr     fdata
	rcall   wbt                   ; десятые
	inc     fadr1
	rcall   wbt                   ; секунды
	inc     fadr1
	rcall   wbt                   ; минуты
	inc     fadr1
	rcall   wbt                   ; часы
;-------------------------------------------------
	clr     wreg
	sts     reg4,wreg
	sts     reg5,wreg
	sts     reg6,wreg
	sts     reg7,wreg
	ret
;===================================================================
; если не 0 - загоняем обратно в регистры в инверсном виде
time_ret:
	lds     wreg,th
	sbr     wreg,$80
	sts     reg4,wreg
;----------------------------------------------------------
	lds     wreg,tm1
	swap    wreg
	lds     arif1,tm2
	or      wreg,arif1
	sts     reg5,wreg
;----------------------------------------------------------
	lds     wreg,ts1
	swap    wreg
	lds     arif1,ts2
	or      wreg,arif1
	sts     reg6,wreg
;----------------------------------------------------------
	ldi     wreg,0
	sts     reg7,wreg
	ret
;***********************************************************************
;************ ВЫЧИТАНИЕ ВРЕМЕНИ ****************************************
;***********************************************************************
t_minus_r:
; вычитаем из вычисляемого реальное  --- в вычисляемое ( ПРЕОБРАЗОВАНИЕ ФОРМЫ )
	lds     wreg,ts2
	lds     bufer,rs2
	sub     wreg,bufer
	brcc    znak2_form             ; в регистре wreg - результат
; если перенос - преобразуем в 1 - 9
	com     wreg                   ; инверсия
	ldi     bufer,$09
	sub     bufer,wreg
	mov     wreg,bufer             ; в регистре wreg - результат
	sec                            ; в переносе - перенос
;-------------------------------------------------------------------
znak2_form:
	sts     ts2,wreg
	lds     wreg,ts1
	lds     bufer,rs1
	sbc     wreg,bufer
	brcc    znak3_form             ; в регистре wreg - результат
; если перенос - преобразуем в 1 - 6
	com     wreg                   ; инверсия
	ldi     bufer,$05
	sub     bufer,wreg
	mov     wreg,bufer             ; в регистре wreg - результат
	sec                            ; в переносе - перенос
;-------------------------------------------------------------------
znak3_form:
	sts     ts1,wreg
	lds     wreg,tm2
	lds     bufer,rm2
	sbc     wreg,bufer
	brcc    znak4_form             ; в регистре wreg - результат
; если перенос - преобразуем в 1 - 9
	com     wreg                   ; инверсия
	ldi     bufer,$09
	sub     bufer,wreg
	mov     wreg,bufer             ; в регистре wreg - результат
	sec                            ; в переносе - перенос
;-------------------------------------------------------------------
znak4_form:
	sts     tm2,wreg
	lds     wreg,tm1
	lds     bufer,rm1
	sbc     wreg,bufer
	brcc    znak5_form             ; в регистре wreg - результат
; если перенос - преобразуем в 1 - 6
	com     wreg                   ; инверсия
	ldi     bufer,$05
	sub     bufer,wreg
	mov     wreg,bufer             ; в регистре wreg - результат
	sec                            ; в переносе - перенос
;-------------------------------------------------------------------
znak5_form:
	sts     tm1,wreg
	lds     wreg,th
	lds     bufer,rh
	sbc     wreg,bufer
	brcc    znak6_form          ; в регистре wreg - результат
; если перенос - преобразуем в 1 - 9
	com     wreg                   ; инверсия
	ldi     bufer,$09
	sub     bufer,wreg
	mov     wreg,bufer             ; в регистре wreg - результат
;------------------------------------------------------------------
znak6_form:
	sts     th,wreg
	ret
;***********************************************************************
;*********ПЕРЕДАЧА БАЙТА ВНИЗ*******************************************
;***********************************************************************
; передать байт из rs232 с 9 битом
outrs:  cbi     PORTB,1        ; стартовый
	rcall   z100
	ldi     wreg,8         ; счетчик битов
	mov     rc,wreg
;--------------------------------------------------------------------------
cikl_outrs:
	sbrs    rs232,0
	rjmp    setrs0
setrs1:
	sbi     PORTB,1
	rjmp    nxtrs
setrs0:
	cbi     PORTB,1
nxtrs:
	rcall   z100
	dec     rc
	breq    outrs9         ; если байт передан - посылка стопбита,
        ror     rs232          ; иначе  следующий бит
	rjmp    cikl_outrs
;-------------------------------------------------------------------
outrs9:
	sbrs    fl,TX9
	rjmp    rs90
rs91:
	sbi     PORTB,1
	rjmp    stop
rs90:
	cbi     PORTB,1
stop:
	rcall   z100
	sbi     PORTB,1        ;        выдать стоповый бит
	rcall   z100
	ret
;***********************************************************************
;***********ПРИЕМ БАЙТА СНИЗУ*******************************************
;***********************************************************************
inrs:   ; стартовый бит уже пришел
	clr     rs232
        cbr     fl,$04         ; сброс ошибки
	ldi     wreg,8         ; счетчик битов
	mov     rc,wreg
	rcall   z25
	rcall   z25
	sbic    PINB,0         ; проверка стартового
	rjmp    errs
inrs1:
	rcall   z100
	lsr     rs232
	sbic    PINB,0        ; анализ состояния порта в середине бита
	rjmp    se1
se0:    cbr     rs232,$80          ; установка 0
        rjmp    nexb
se1:    sbr     rs232,$80          ; установка 1
nexb:   dec     rc              ; проверка на окончание 8 бит
	brne    inrs1
        rcall   z100
	sbis    PINB,0

errs:   sbr     fl,$04            ; установка флага ошибки
	ret
;***********************************************************************
;*********ПЕРЕДАЧА БАЙТА************************************************
;***********************************************************************
outbyte:
	out     UDR,wreg
ogout1:
	sbis    USR,TXC
	rjmp    ogout1
	rcall	z250
	rcall	z250
	ret
;***********************************************************************


;***********************************************************************
;*************ПОДПРОГРАММА ОПРЕДЕЛЕНИЯ АДРЕСА***************************
;***********************************************************************
opr_adr:
	lds     fadr2,sob2
	lds     fadr1,sob1            ; определяем адрес текущей ячейки
	lsl     fadr1
	rol     fadr2
	lsl     fadr1
	rol     fadr2
	lsl     fadr1
	rol     fadr2
	ret
;***********************************************************************
;*************ПОДПРОГРАММА ОПРЕДЕЛЕНИЯ АДРЕСА****************************
;************************************************************************
opr_adr1:
	lds     fadr2,tsob2
	lds     fadr1,tsob1            ; определяем адрес текущей ячейки
	lsl     fadr1
	rol     fadr2
	lsl     fadr1
	rol     fadr2
	lsl     fadr1
	rol     fadr2
	ret
;*************************************************************************
; ПОДПРОГРАММЫ  ЗАДЕРЖКИ
;*************************************************************************
z25:    ldi 	wreg,25                  ; 25 mks
	mov     rz1,wreg
zad:	wdr
	nop
	nop
	nop
	nop			         ; 8 MGz
	dec 	rz1
	brne 	zad
	ret
;*************************************************************************
z100:   ldi 	wreg,102                 ; 100 mks
	mov     rz1,wreg
	rjmp	zad
;************************************************************************
z250:   ldi 	wreg,250                 ; 250 mks
	mov     rz1,wreg
	rjmp    zad
;*************************************************************************
z1ms:   ldi     wreg,4                   ; 1 ms
	mov     rz2,wreg
	rjmp    z30ms1
;*************************************************************************
z5ms:   ldi     wreg,20                   ; 5 ms
	mov     rz2,wreg
	rjmp    z30ms1
;*************************************************************************
z10ms:  ldi     wreg,40                   ; 10 ms
	mov     rz2,wreg
	rjmp    z30ms1
;*************************************************************************
z30ms:
	ldi     wreg,120                  ; 30 ms
	mov     rz2,wreg
z30ms1: wdr
	rcall   z250
	dec 	rz2
	brne 	z30ms1
	ret
;*************************************************************************
z01s:   ldi     wreg,3                    ; 0.1s
	mov     rz3,wreg
	rjmp    z2s1
;*************************************************************************
z05s:   ldi     wreg,15                   ; 0.5s
	mov     rz3,wreg
	rjmp    z2s1
;*************************************************************************
z2s:    ldi     wreg,66                   ; 2s
	mov     rz3,wreg
z2s1:   rcall   z30ms
	dec 	rz3
	brne 	z2s1
	ret
;*************************************************************************
;******************ПОДПРОГРАММЫ ЗВУКА*************************************
;*************************************************************************
sound4:
	ldi     wreg,128                 ; звук высокий
	mov	soun,wreg
; заряжаем таймер на 250 мкс
	ldi     wreg,$23                  ; 8 мкс\ дискрет
	out     TCCR0,wreg
 	ldi	wreg,226	
	out	TCNT0,wreg
; разрешаем прерывания по переполнению
 	ldi	wreg,$02	
	out	TIMSK,wreg
	out	TIFR,wreg
        sei
;-------------------------------------
        ret
;*************************************************************************
sound1:
	ldi     wreg,256                 ; звук высокий
	mov     rz2,wreg
sou1:   sbi     PORTB,5
	rcall   z250
	cbi     PORTB,5
	rcall   z250
	dec 	rz2
	brne 	sou1
	ret
;*************************************************************************
sound2:
	ldi     r16,128                 ; звук cpeний
	mov     rz2,r16
sou2:
	sbi     PORTB,5
	rcall   z250
	rcall   z250
	cbi     PORTB,5
	rcall   z250
	rcall   z250
	dec 	rz2
	brne 	sou2
	ret
;*************************************************************************
sound3:
	ldi     r16,85                 ; звук низкий
	mov     rz2,r16
sou3:   sbi     PORTB,5
	rcall   z250
	rcall   z250
	rcall   z250
	cbi     PORTB,5
	rcall   z250
	rcall   z250
	rcall   z250
	dec 	rz2
	brne 	sou3
	ret
;*************************************************************************
;*************************************************************************
;*******ПОДПРОГРАМЫ ДЛЯ ЧТЕНИЯ IIS-ПАМЯТИ*********************************
;*************************************************************************
;**RRA *****************ЧТЕНИЕ С ПРОИЗВОЛЬНОГО АДРЕСА*********************
;*************************************************************************
; 1. Сфоpмиpовать СТАРТ-условие
; 2. Послать адpес Slave-устpойства   1010 XXX 0 (последний бит-запись)
; 3. Пpовеpить подтвеpждение пpиема
; 4. Послать адpес считываемой ячейки
; 5. Пpовеpить подтвеpждение пpиема
; 4.1. Послать адpес считываемой ячейки  (второй байт)
; 5.1. Пpовеpить подтвеpждение пpиема
; 6. Сфоpмиpовать СТАРТ-условие
; 7. Послать адpес Slave-устpойства   1010XXX1 (последний бит-чтение)
; 8. Пpовеpить подтвеpждение пpиема
; 9. Пpинять последовательно 8 бит данных
; 10. Сфоpмиpовать СТОП- условие
rrat:   ldi     rsa,$A0      ; адрес таймера в пространстве IIS
       	rjmp    rra
rrar:   ldi     rsa,$A2      ; адрес памяти в пространстве IIS
;=========================================================================
rra:   	andi    rsa,$FE      ; сброс младшего бита rsa
	sbi     DDRB,SDA     ; SDA на выход
       	sbi     PORTB,SCL    ;                  еще pаз обе линии
       	sbi     PORTB,SDA    ;  на всякий случай освобождаем
       	ldi     wreg,$08      ; загрузка счетчика
	mov     rc,wreg
	ldi     XL,18        ; подготовка для передачи регистра rsa    !!!
       	cbi     PORTB,SDA    ; сбpос линии данных - СТАРТ-условие
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    rra
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
; Пеpедача контpольного байта закончена
;************************************************************************
	cpi     rsa,$A2      ; сравниваем адрес с адресом памяти
	brne    adr1         ; если не память - то только 1 адрес
;-----------------------------------------------------------
       	ldi     XL,9         ; подготовка для передачи регистра fadr2    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    rra
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
;-----------------------------------------------------------
adr1:   ldi     XL,10        ; подготовка для передачи регистра fadr1    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    rra
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
	cbi     PORTB,SCL    ; окончание импульса подтверждения
;  Пеpедача адpеса закончена
;************************************************************************
       	sbi     PORTB,SDA    ;                  еще pаз обе линии
       	sbi     PORTB,SCL    ; на всякий случай освобождаем
	ori     rsa,$01      ; устанавливаем младший бит регистра rsa (чтение)
       	ldi     XL,18        ; подготовка для передачи регистра rsa    !!!
       	cbi     PORTB,SDA    ; сбpос линии данных - СТАРТ-условие
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    rra
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
; Пеpедача контpольного байта закончена
;************************************************************************
; для пpиема данных подготовлен pегистp fdata
        rcall   priem        ; подпpогpамма пpиема байта
	cbi     PORTB,SCL    ; окончание импульса подтверждения
	cbi     PORTB,SDA    ; сброс линии данных
	sbi     PORTB,SCL    ; установка SCL
	sbi     PORTB,SDA    ; 1 на SDA - СТОП-условие
; Пpием байта окончен
       	ret
;*************************************************************************
;**RCA *****************ЧТЕНИЕ С ТЕКУЩЕГО АДРЕСА**************************
;*************************************************************************
rcat:   ldi     rsa,$A0      ; адрес таймера в пространстве IIS
       	rjmp    rca
rcar:   ldi     rsa,$A2      ; адрес памяти в пространстве IIS
;=========================================================================
rca:   	ori     rsa,$01      ; установка младшего бита rsa
	sbi     DDRB,SDA     ; SDA на выход
       	sbi     PORTB,SCL    ;                  еще pаз обе линии
       	sbi     PORTB,SDA    ; на всякий случай освобождаем
       	ldi     wreg,$08      ; загрузка счетчика
	mov     rc,wreg
	ldi     XL,18        ; подготовка для передачи регистра rsa    !!!
       	cbi     PORTB,SDA    ; сбpос линии данных - СТАРТ-условие
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    rca
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
; Пеpедача контpольного байта закончена
;************************************************************************
; для пpиема данных подготовлен pегистp fdata
        rcall   priem        ; подпpогpамма пpиема байта
	cbi     PORTB,SCL    ; окончание импульса подтверждения
	cbi     PORTB,SDA    ; сброс линии данных
	sbi     PORTB,SCL    ; установка SCL
        sbi     PORTB,SDA    ; 1 на SDA - СТОП-условие
; Пpием байта окончен
       	ret
;*************************************************************************
;**WB*******************ЗАПИСЬ БАЙТА**************************************
;*************************************************************************
; 1. Сфоpмиpовать СТАРТ-условие
; 2. Послать адpес Slave-устpойства   1010XXX0 (последний бит-запись)
; 3. Пpовеpить подтвеpждение пpиема
; 4. Послать адpес записываемой ячейки
; 5. Пpовеpить подтвеpждение пpиема
; 6. Пеpеслать байт данных
; 7. Пpовеpить подтвеpждение пpиема
; 8. Сфоpмиpовать СТОП- условие
wbt:    ldi     rsa,$A0      ; адрес таймера в пространстве IIS
       	rjmp    wb
wbr:    ldi     rsa,$A2      ; адрес памяти в пространстве IIS
;=========================================================================
wb:   	andi    rsa,$FE      ; сброс младшего бита rsa
	sbi     DDRB,SDA     ; SDA на выход
       	sbi     PORTB,SCL    ;                  еще pаз обе линии
       	sbi     PORTB,SDA    ; на всякий случай освобождаем
       	ldi     wreg,$08      ; загрузка счетчика
	mov     rc,wreg
	ldi     XL,18        ; подготовка для передачи регистра rsa    !!!
       	cbi     PORTB,SDA    ; сбpос линии данных - СТАРТ-условие
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wb
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
; Пеpедача контpольного байта закончена
;************************************************************************
	cpi     rsa,$A2      ; сравниваем адрес с адресом памяти
	brne    adr2         ; если не память - то только 1 адрес
;-----------------------------------------------------------
       	ldi     XL,9         ; подготовка для передачи регистра fadr2    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wb
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
;-----------------------------------------------------------
adr2:   ldi     XL,10        ; подготовка для передачи регистра fadr1    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wb
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
	cbi     PORTB,SCL    ; окончание импульса подтверждения
;  Пеpедача адpеса закончена
;************************************************************************
       	ldi     XL,11        ; подготовка для передачи регистра fdata    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	cbi     PORTB,SDA    ; отключение резистора;
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wb
	sbi     PORTB,SDA    ; подключение резистора
	sbi     DDRB,SDA     ; SDA на выход
; генирим СТОП-условие
	cbi     PORTB,SCL    ; окончание импульса подтверждения
	cbi     PORTB,SDA    ; сброс линии данных
	sbi     PORTB,SCL    ; установка SCL
        sbi     PORTB,SDA    ; 1 на SDA - СТОП-условие
; Пpием байта окончен
	ret
;*************************************************************************
;**PW*******************ЗАПИСЬ СТРАНИЦЫ***********************************
;*************************************************************************
; 1. Сфоpмиpовать СТАРТ-условие
; 2. Послать адpес Slave-устpойства   1010XXX0 (последний бит-запись)
; 3. Пpовеpить подтвеpждение пpиема
; 4. Послать адpес записываемой ячейки
; 5. Пpовеpить подтвеpждение пpиема
; 6. Пеpеслать байт данных 64 раза
; 7. Пpовеpить подтвеpждение пpиема
; 8. Сфоpмиpовать СТОП- условие
wpr:    ldi     rsa,$A2      ; адрес памяти в пространстве IIS
       	rjmp    wp
;=========================================================================
wp:   	andi    rsa,$FE      ; сброс младшего бита rsa
	sbi     DDRB,SDA     ; SDA на выход
       	sbi     PORTB,SCL    ;                  еще pаз обе линии
       	sbi     PORTB,SDA    ; на всякий случай освобождаем
       	ldi     wreg,$08      ; загрузка счетчика
	mov     rc,wreg
	ldi     XL,18        ; подготовка для передачи регистра rsa    !!!
       	cbi     PORTB,SDA    ; сбpос линии данных - СТАРТ-условие
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	nop
	cbi     PORTB,SDA    ; отключение резистора;nop
	nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wp
	sbi     PORTB,SDA    ; подключение резистора
	nop
	sbi     DDRB,SDA     ; SDA на выход
; Пеpедача контpольного байта закончена
;************************************************************************
       	ldi     XL,9         ; подготовка для передачи регистра fadr2    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	nop
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wp
	sbi     PORTB,SDA    ; подключение резистора
	nop
	sbi     DDRB,SDA     ; SDA на выход
;-----------------------------------------------------------
        ldi     XL,10        ; подготовка для передачи регистра fadr1    !!!
       	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	nop
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wp
	sbi     PORTB,SDA    ; подключение резистора
	nop
	sbi     DDRB,SDA     ; SDA на выход
	nop
	cbi     PORTB,SCL    ; окончание импульса подтверждения
;  Пеpедача адpеса закончена
;************************************************************************
bw:     ldi     XL,reg1      ; запись адреса первого байта
bw1:   	rcall   treg         ; подпpогpама пеpедачи pегистpа
       	cbi     DDRB,SDA     ; SDA на вход
	nop
	cbi     PORTB,SDA    ; отключение резистора;nop
	sbic    PINB,SDA     ; анализ подтвеpждения  пpиема байта
	rjmp    wp
	sbi     PORTB,SDA    ; подключение резистора
	nop
	sbi     DDRB,SDA     ; SDA на выход
; проверяем о какой странице идет речь
	cpi     XL,reg8      ; сравниваем XL c const
	sbrc    fl,BIGP      ;  проверяем флаг длинной страницы
	cpi     XL,reg32     ; сравниваем XL c const
	breq    stusl        ; если уже конец - на стоп
	inc     XL
	rjmp    bw1
; генирим СТОП-условие
stusl: 	cbi     PORTB,SCL    ; окончание импульса подтверждения
	nop
	cbi     PORTB,SDA    ; сброс линии данных
	nop
	sbi     PORTB,SCL    ; установка SCL
        nop
	sbi     PORTB,SDA    ; 1 на SDA - СТОП-условие
; Пpием байта окончен
	ret
;*************************************************************************
;***********ПОДПРОГРАММА ПЕРЕСЫЛКИ СОДЕРЖИМОГО РЕГИСТРА*******************
;*************************************************************************
; Подпpогpамма начинается pазpешением установки 1 бита данных
treg:   ld      bufer,X          ; косвенно грузим регистр  bufer
treg1:	cbi     PORTB,SCL        ; 0 на SCL - pазpешено изменение данных
	sbrs    bufer,7          ; пpовеpяем стаpший бит pегистpа
        rjmp    tr0              ; если 0 - пеpедаем 0
        sbi     PORTB,SDA        ; 1 на  SDA
        rjmp    nsi              ; начать новый синхpоимпульс
tr0:    cbi     PORTB,SDA        ; 0 на  SDA
nsi:    nop
        sbi     PORTB,SCL        ; 1 на  SCL
        rol     bufer            ; cдвиг pегистpа
	dec     rc               ; пpовеpяем на окончание байта
        brne    treg1            ; если не конец повтоpить
;---------------------------------------------------------------------
	cbi     PORTB,SCL        ; 0 на SCL - пеpедача байта закончена
        sbi     PORTB,SDA        ; 1 на  SDA
	ldi     r16,$08
	mov     rc,r16
        sbi     PORTB,SCL        ; начало синхpоимпульса подтвеpждения
	ret
; Подпpгpамма заканчивается выставлением высокого уpовня
; синхpоимпульса подтвеpждения по линии SCL (SDA- высокий уpовень)
; Анализ подтвеpждения должен пpоизводиться в основной пpогpамме
;*************************************************************************
;***********ПОДПРОГРАММА ПРИЕМА СОДЕРЖИМОГО АДРЕСОВАННОЙ ЯЧЕЙКИ***********
;*************************************************************************
; Подпpогpамма начинается pазpешением установки 1 бита данных
priem:  cbi     PORTB,SCL   	; окончание импульса подтвеpждения адpесной посылки
       	cbi     DDRB,SDA    	; SDA на вход
	cbi     PORTB,SDA       ; отключение резистора
priem1:	rol     bufer        	; лишний сдвиг pегистpа пеpед пpиемом
	sbi     PORTB,SCL       ; 1 на SCL - данные достовеpны
	nop
	sbis    PINB,SDA        ; анализ линии данных
       	rjmp    pr0
	ori     bufer,$01       ; установка младшего бита
       	rjmp    nxsi
pr0:   	andi    bufer,$FE       ; сброс младшего бита

nxsi:  	cbi     PORTB,SCL       ; 0 на SCL данные на шине меняются
	dec     rc
	brne    priem1
	ldi     r16,$08         ; в pегистp счетчик восстанавливаем 8
	mov     rc,r16
	sbi     PORTB,SCL       ; линия стpобов в 1
	sbi     DDRB,SDA    	; SDA на выход c 0
	mov     fdata,bufer     ; соображаем собранное в регистр FDATA
	ret
; Подпpгpамма заканчивается выставлением высокого уpовня
; синхpоимпульса подтвеpждения по линииSCL (SDA- низкий уpовень)
; Генеpация подтвеpждения или СТОП-условия должна пpоизводиться
; в основной пpогpамме
;*************************************************************************
;*************************************************************************
	; КОНСТАНТЫ
.org	$F80
