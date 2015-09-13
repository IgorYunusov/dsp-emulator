unit sms;

interface
uses sdl2,{$IFDEF WINDOWS}windows,{$ENDIF}
     nz80,lenguaje,main_engine,controls_engine,tms99xx,sn_76496,sysutils,dialogs,
     rom_engine,misc_functions,sound_engine,file_engine,pal_engine;

procedure Cargar_sms;
procedure sms_principal;
function iniciar_sms:boolean;
procedure reset_sms;
procedure cerrar_sms;
procedure sms_sound_update;
//Snapshot
function abrir_sms:boolean;
procedure sms_grabar_snapshot;
//CPU
function sms_getbyte(direccion:word):byte;
procedure sms_putbyte(direccion:word;valor:byte);
function sms_inbyte(puerto:word):byte;
procedure sms_outbyte(valor:byte;puerto:word);
procedure sms_interrupt(int:boolean);

const
        sms_bios:tipo_roms=(n:'sms.rom';l:$2000;p:0;crc:$3aa93ef3);
        keycodes:array[0..15] of byte=($0A,$0D,$07,$0C,$02,$03,$0E,$05,$01,$0B,$06,$09,$0F,$0F,$0F,$0F);
var
  njoymode:boolean;
  nJoyState:array[0..1] of Integer;
  mapper_reg:array[0..3] of byte;

implementation
uses principal;

procedure Cargar_sms;
begin
principal1.Panel2.Visible:=true;
principal1.BitBtn9.visible:=false;
principal1.BitBtn10.Enabled:=true;
principal1.BitBtn10.Glyph:=nil;
principal1.imagelist2.GetBitmap(4,principal1.BitBtn10.Glyph);
principal1.BitBtn10.visible:=true;
principal1.BitBtn10.OnClick:=principal1.fLoadCartucho;
principal1.BitBtn11.visible:=true;
principal1.BitBtn11.Enabled:=true;
principal1.BitBtn12.visible:=false;
principal1.BitBtn14.visible:=false;
llamadas_maquina.iniciar:=iniciar_sms;
llamadas_maquina.bucle_general:=sms_principal;
llamadas_maquina.cerrar:=cerrar_sms;
llamadas_maquina.reset:=reset_sms;
llamadas_maquina.cartuchos:=abrir_sms;
llamadas_maquina.grabar_snapshot:=sms_grabar_snapshot;
llamadas_maquina.fps_max:=60;
end;

function iniciar_sms:boolean;
var
  longitud:integer;
begin
iniciar_sms:=false;
iniciar_audio(false);
screen_init(1,352,262);
iniciar_video(352,262);
//Main CPU
main_z80:=cpu_z80.create(3579545,1);
main_z80.change_ram_calls(sms_getbyte,sms_putbyte);
main_z80.change_io_calls(sms_inbyte,sms_outbyte);
main_z80.init_sound(sms_sound_update);
//TMS
TMS99XX_Init(1);
tms.IRQ_Handler:=sms_interrupt;
//Chip Sonido
sn_76496_0:=sn76496_chip.Create(3579545);
//cargar roms
//if not(read_file_size('c:\dsp\sms\Teddy Boy (UEB) [!].sms',longitud)) then exit;
//if not(read_file('c:\dsp\sms\Teddy Boy (UEB) [!].sms',@memoria[$4000],longitud)) then begin
//      exit;
//    end;
if not(read_file_size('c:\dsp\sms\mpr-12808.ic2',longitud)) then exit;
if not(read_file('c:\dsp\sms\mpr-12808.ic2',@memoria[$0],longitud)) then begin
      exit;
    end;
//final
reset_sms;
iniciar_sms:=true;
end;

procedure cerrar_sms;
begin
main_z80.free;
sn_76496_0.Free;
TMS99XX_close;
close_audio;
close_video;
end;

procedure reset_sms;
begin
 main_z80.reset;
 sn_76496_0.reset;
 TMS99XX_reset;
 reset_audio;
 njoymode:=false;
 nJoyState[0]:=0;
 nJoyState[1]:=$FFFF;
end;

procedure sms_principal;
var
  frame:single;
begin
init_controls(false,true,true,false);
frame:=main_z80.tframes;
while EmuStatus=EsRuning do begin
  main_z80.run(frame);
  frame:=frame+main_z80.tframes-main_z80.contador;
  //TMS99XX_Interrupt;
  //TMS99XX_refresh;
  //actualiza_trozo_simple(0,0,256+BORDER*2,192+BORDER*2,1);
  video_sync;
end;
end;

function sms_getbyte(direccion:word):byte;
begin
case direccion of
  0..$bfff:sms_getbyte:=memoria[direccion];
  $c000..$dfff:sms_getbyte:=memoria[direccion];
  $e000..$fffb:sms_getbyte:=memoria[direccion-$2000];
  $fffc..$ffff:sms_getbyte:=mapper_reg[direccion and $3];
end;
end;

procedure sms_putbyte(direccion:word;valor:byte);
begin
if direccion<$7fff then exit;
case direccion of
  $8000..$bfff:memoria[direccion]:=valor;
  $c000..$dfff:memoria[direccion]:=valor;
  $e000..$fffb:memoria[direccion-$2000]:=valor;
  $fffc..$ffff:begin //Mapper registers
                  mapper_reg[direccion and $3]:=valor;
                  case (direccion and $3) of
                    0:begin //RAM register
                      end;
                    1:begin //Page 0 ROM bank
                      end;
                    2:begin //Page 1 ROM bank
                      end;
                    3:begin //Page 2 ROM bank
                      end;
                  end;
               end;
end;
end;

function sms_inbyte(puerto:word):byte;
var
  nPAux: Integer;
  nResult:byte;
begin
  nResult:=$FF;
  case (puerto and $ff) of
    $40..$7f:halt(0);
    $80..$bf:if (puerto and $01)<>0 then nResult:=TMS99XX_register_r
          else nResult:=TMS99XX_vram_r;
    $dc,$dd:nResult:=$ff; //Joystick
  end;
  sms_inbyte:=nResult;
end;

procedure sms_outbyte(valor:byte;puerto:word);
begin
  case (puerto and $ff) of
    $40..$7f:sn_76496_0.Write(valor);
    $80..$bf:if (puerto and $01)<>0 then TMS99XX_register_w(valor)
          else TMS99XX_vram_w(valor);
  end;
end;

procedure sms_interrupt(int:boolean);
begin
  if int then main_z80.pedir_irq:=HOLD_LINE;
end;

procedure sms_sound_update;
begin
  sn_76496_0.update;
end;

function sms_cargar_snapshot(data:pbyte;long:dword):boolean;
var
  f:byte;
  cadena:string;
  longitud,comprimido,descomprimido:integer;
  ptemp,ptemp2:pbyte;
  main_z80_reg:npreg_z80;
  version:word;
begin
sms_cargar_snapshot:=false;
longitud:=0;
for f:=0 to 3 do begin
  cadena:=cadena+chr(data^);
  inc(data);
end;
//Todos las cabeceras tienen 10bytes
if cadena<>'CLSN' then exit;
reset_sms;
version:=data^ shl 8; //Version
inc(data);
version:=version or data^;
if ((version<>$100) and (version<>$200) and (version<>$210)) then exit;
inc(data,5);inc(longitud,10);
while longitud<>long do begin
  if longitud>long then exit;
  cadena:='';
  for f:=0 to 3 do begin
        cadena:=cadena+chr(data^);
        inc(data);inc(longitud);
  end;
  if cadena='CRAM' then begin
    copymemory(@comprimido,data,4);
    inc(data,6);inc(longitud,6);
    getmem(ptemp,$e000);
    decompress_zlib(data,comprimido,pointer(ptemp),descomprimido);
    copymemory(@memoria[$2000],ptemp,$e000);
    freemem(ptemp);
    inc(data,comprimido);inc(longitud,comprimido);
  end;
  if cadena='Z80R' then begin
    comprimido:=0;
    copymemory(@comprimido,data,2);
    inc(data,6);inc(longitud,6);
    case version of
     $100:begin //Version 1.00
        { 68 bytes:
        ppc,pc,sp:word;
        bc,de,hl:parejas;
        bc2,de2,hl2:parejas;
        ix,iy:parejas;
        iff1,iff2,halt:boolean;
        pedir_irq,pedir_nmi,nmi_state:byte;
        a,a2,i,r:byte;
        f,f2:band_z80;
        contador:dword;
        im,im2_lo,im0:byte;
        daisy,opcode,after_ei:boolean;
        numero_cpu:byte;
        tframes:single;
        enabled:boolean;
        estados_demas:word;}
          getmem(ptemp2,comprimido);
          ptemp:=ptemp2;
          copymemory(ptemp,data,comprimido);
          getmem(main_z80_reg,sizeof(nreg_z80));
          copymemory(@main_z80_reg.ppc,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.pc,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.sp,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.bc.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.de.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.hl.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.bc2.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.de2.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.hl2.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.ix.w,ptemp,2);inc(ptemp,2);
          copymemory(@main_z80_reg.iy.w,ptemp,2);inc(ptemp,2);
          main_z80_reg.iff1:=(ptemp^<>0);inc(ptemp);
          main_z80_reg.iff2:=(ptemp^<>0);inc(ptemp);
          main_z80.halt:=(ptemp^<>0);inc(ptemp);
          main_z80.pedir_irq:=ptemp^;inc(ptemp);
          main_z80.pedir_nmi:=ptemp^;inc(ptemp);
          {main_z80.nmi_state:=(ptemp^<>0);}inc(ptemp);
          main_z80_reg.a:=ptemp^;inc(ptemp);
          main_z80_reg.a2:=ptemp^;inc(ptemp);
          main_z80_reg.i:=ptemp^;inc(ptemp);
          main_z80_reg.r:=ptemp^;inc(ptemp);
          main_z80_reg.f.s:=(ptemp^ and 128)<>0;inc(ptemp);
          main_z80_reg.f.z:=(ptemp^ and 64)<>0;inc(ptemp);
          main_z80_reg.f.bit5:=(ptemp^ and 32)<>0;inc(ptemp);
          main_z80_reg.f.h:=(ptemp^ and 16)<>0;inc(ptemp);
          main_z80_reg.f.bit3:=(ptemp^ and 8)<>0;inc(ptemp);
          main_z80_reg.f.p_v:=(ptemp^ and 4)<>0;inc(ptemp);
          main_z80_reg.f.n:=(ptemp^ and 2)<>0;inc(ptemp);
          main_z80_reg.f.c:=(ptemp^ and 1)<>0;inc(ptemp);
          main_z80_reg.f2.s:=(ptemp^ and 128)<>0;inc(ptemp);
          main_z80_reg.f2.z:=(ptemp^ and 64)<>0;inc(ptemp);
          main_z80_reg.f2.bit5:=(ptemp^ and 32)<>0;inc(ptemp);
          main_z80_reg.f2.h:=(ptemp^ and 16)<>0;inc(ptemp);
          main_z80_reg.f2.bit3:=(ptemp^ and 8)<>0;inc(ptemp);
          main_z80_reg.f2.p_v:=(ptemp^ and 4)<>0;inc(ptemp);
          main_z80_reg.f2.n:=(ptemp^ and 2)<>0;inc(ptemp);
          main_z80_reg.f2.c:=(ptemp^ and 1)<>0;inc(ptemp);
          copymemory(@main_z80.contador,ptemp,4);inc(ptemp,4);
          main_z80_reg.im:=ptemp^;inc(ptemp);
          main_z80.im2_lo:=ptemp^;inc(ptemp);
          main_z80.im0:=ptemp^;
          main_z80.set_internal_r(main_z80_reg);
          freemem(ptemp2);
      end;
      $200:begin //Version 2.00
          main_z80_reg:=main_z80.get_internal_r;
          ptemp:=data;
          copymemory(main_z80_reg,ptemp,comprimido-9);
          inc(ptemp,comprimido-9);
          //resto
          main_z80.halt:=(ptemp^<>0);inc(ptemp);
          main_z80.pedir_irq:=ptemp^;inc(ptemp);
          main_z80.pedir_nmi:=ptemp^;inc(ptemp);
          copymemory(@main_z80.contador,ptemp,4);inc(ptemp,4);
          main_z80.im2_lo:=ptemp^;inc(ptemp);
          main_z80.im0:=ptemp^;inc(ptemp);
        end;
      $210:main_z80.load_snapshot(data); //Version 2.10
    end;
    inc(data,comprimido);inc(longitud,comprimido);
  end;
  if cadena='TMSR' then begin
    copymemory(@comprimido,data,4);
    inc(data,6);inc(longitud,6);
    getmem(ptemp,sizeof(TTMS99XX));
    decompress_zlib(data,comprimido,pointer(ptemp),descomprimido);
    copymemory(TMS,ptemp,descomprimido);
    freemem(ptemp);
    inc(data,comprimido);inc(longitud,comprimido);
    if tms.bgcolor=0 then paleta[0]:=0
      else paleta[0]:=paleta[tms.bgcolor];
  end;
  if cadena='7649' then begin
    copymemory(@comprimido,data,4);
    inc(data,6);inc(longitud,6);
    sn_76496_0.load_snapshot(data);
    inc(data,comprimido);inc(longitud,comprimido);
  end;
end;
sms_cargar_snapshot:=true;
end;

function abrir_cartucho(datos:pbyte;longitud:integer):boolean;
var
  ptemp:pbyte;
begin
abrir_cartucho:=false;
ptemp:=datos;
inc(ptemp,1);
if not(((datos^=$55) and (ptemp^=$aa)) or ((datos^=$aa) and (ptemp^=$55)) or ((datos^=$66) and (ptemp^=$99))) then exit;
reset_sms;
copymemory(@memoria[$8000],datos,longitud);
abrir_cartucho:=true;
end;

function abrir_sms:boolean;
var
  extension,nombre_file,RomFile:string;
  datos:pbyte;
  longitud,crc:integer;
begin
  exit;
  if not(OpenRom(Stcolecovision,Romfile)) then begin
    abrir_sms:=true;
    exit;
  end;
  abrir_sms:=false;
  extension:=extension_fichero(RomFile);
  if extension='ZIP' then begin
    if not(search_file_from_zip(RomFile,'*.col',nombre_file,longitud,crc,false)) then
      if not(search_file_from_zip(RomFile,'*.rom',nombre_file,longitud,crc,false)) then
        if not(search_file_from_zip(RomFile,'*.bin',nombre_file,longitud,crc,false)) then
          if not(search_file_from_zip(RomFile,'*.csn',nombre_file,longitud,crc,true)) then exit;
    getmem(datos,longitud);
    if not(load_file_from_zip(RomFile,nombre_file,datos,longitud,crc,true)) then begin
      freemem(datos);
      exit;
    end;
  end else begin
    if ((extension<>'COL') and (extension<>'ROM') and (extension<>'BIN') and (extension<>'CSN')) then exit;
    if not(read_file_size(RomFile,longitud)) then exit;
    getmem(datos,longitud);
    if not(read_file(RomFile,datos,longitud)) then begin
      freemem(datos);
      exit;
    end;
    nombre_file:=extractfilename(RomFile);
  end;
directory.colecoVision:=ExtractFilePath(romfile);
extension:=extension_fichero(nombre_file);
if extension='CSN' then begin
  if not(sms_cargar_snapshot(datos,longitud)) then begin
    freemem(datos);
    exit;
  end;
end;
if ((extension='COL') or (extension='ROM') or (extension='BIN')) then begin
  if not(abrir_cartucho(datos,longitud)) then begin
    freemem(datos);
    exit;
  end;
end;
freemem(datos);
change_caption(llamadas_maquina.caption+' - '+nombre_file);
//Restauro la llamada de interrupcion del TMS
tms.IRQ_Handler:=sms_interrupt;
abrir_sms:=true;
end;

procedure sms_grabar_snapshot;
var
  cantidad,long_final,comprimido:integer;
  buffer:array[0..9] of byte;  //Cabecera de los bloques siempre 10bytes
  nombre:string;
  puntero,datos_final,data:pbyte;
  ptemp:pointer;
begin
exit;
principal1.savedialog1.InitialDir:=Directory.coleco_snap;
principal1.saveDialog1.Filter := 'CSN Format (*.csn)|*.csn';
if principal1.savedialog1.execute then begin
        nombre:=changefileext(principal1.savedialog1.FileName,'.csn');
        if FileExists(nombre) then begin                                         //Respuesta 'NO' es 7
            if MessageDlg(leng[main_vars.idioma].mensajes[3], mtWarning, [mbYes]+[mbNo],0)=7 then exit;
        end;
end else exit;
long_final:=0;
getmem(datos_final,139400);
data:=datos_final;
//Cabecera
buffer[0]:=ord('C'); //Nombre Bloque
buffer[1]:=ord('L');
buffer[2]:=ord('S');
buffer[3]:=ord('N');
buffer[4]:=2; //version 2.1, nuevos procesos load/save Z80
buffer[5]:=$10;
buffer[6]:=0;buffer[7]:=0;buffer[8]:=0;buffer[9]:=0; //reservado
copymemory(data,@buffer[0],10);
inc(data,10);inc(long_final,10);
//sms RAM longitud=$e000
buffer[0]:=ord('C');
buffer[1]:=ord('R');
buffer[2]:=ord('A');
buffer[3]:=ord('M');
buffer[6]:=0;buffer[7]:=0;buffer[8]:=0;buffer[9]:=0;  //reservado
getmem(puntero,$e000);
ptemp:=@memoria[$2000];
compress_zlib(ptemp,$e000,pointer(puntero),comprimido);
buffer[4]:=comprimido mod 256; //longitud
buffer[5]:=comprimido div 256; //longitud
copymemory(data,@buffer[0],10);
inc(data,10);inc(long_final,10);
copymemory(data,puntero,comprimido);
inc(data,comprimido);inc(long_final,comprimido);
freemem(puntero);
//TMS9918 longitud=81960
cantidad:=sizeof(TTMS99XX);
buffer[0]:=ord('T');
buffer[1]:=ord('M');
buffer[2]:=ord('S');
buffer[3]:=ord('R');
buffer[7]:=0;buffer[8]:=0;buffer[9]:=0;
getmem(puntero,cantidad);
ptemp:=pointer(TMS);
compress_zlib(ptemp,cantidad,pointer(puntero),comprimido);
buffer[4]:=(comprimido mod 65536) and $ff;
buffer[5]:=(comprimido mod 65536) shr 8;
buffer[6]:=comprimido div 65536;
copymemory(data,@buffer[0],10);
inc(data,10);inc(long_final,10);
copymemory(data,puntero,comprimido);
inc(data,comprimido);inc(long_final,comprimido);
freemem(puntero);
//Z80
getmem(puntero,100);
cantidad:=main_z80.save_snapshot(puntero);
buffer[0]:=ord('Z');
buffer[1]:=ord('8');
buffer[2]:=ord('0');
buffer[3]:=ord('R');
buffer[4]:=cantidad;
buffer[5]:=0;buffer[6]:=0;buffer[7]:=0;buffer[8]:=0;buffer[9]:=0;
copymemory(data,@buffer[0],10);
inc(data,10);inc(long_final,10);
copymemory(data,puntero,cantidad);
inc(data,cantidad);inc(long_final,cantidad);
freemem(puntero);
//Sound
getmem(puntero,200);
cantidad:=sn_76496_0.save_snapshot(puntero);
buffer[0]:=ord('7');
buffer[1]:=ord('6');
buffer[2]:=ord('4');
buffer[3]:=ord('9');
buffer[4]:=cantidad;
buffer[5]:=0;buffer[6]:=0;buffer[7]:=0;buffer[8]:=0;buffer[9]:=0;
copymemory(data,@buffer[0],10);
inc(data,10);inc(long_final,10);
copymemory(data,puntero,cantidad);
inc(long_final,cantidad);
freemem(puntero);
//Final
write_file(nombre,datos_final,long_final);
freemem(datos_final);
end;

end.