Import brl
Import mojo

Const CC:= 100000000
Const EOI:= 200000000

Class GifReader
  
  Field s:DataStream
  Field gif:Gif
  Field frame:Frame 'Temporary frame
  Field numberOfFrames:Int
  Field tempGraphicControl:GraphicControlExtension 'Temporary
  Field i:Int 'Temporary
  Field j:Int 'Temporary
  Field loaded:= False 
  
  '-------------GIF Header-------------
  'Header Block
  Field Header_type:String
  Field Header_version:String
  Field Header_width:Int
  Field Header_height:Int
  'Logical Screen Descriptor
  Field Header_hasGlobalColorTable:Bool
  Field Header_colorResolution:Int 'TODO
  Field Header_sort:Bool
  Field Header_sizeGCT:Int 'Size of global color table
  Field Header_backgroundColorIndex:Int
  Field Header_pixelAspectRatio:Int
  'Global Color Table
  Field Header_GCT:Int[] 'Global color table
  
  '-------------Player Stuff-------------
  Field updates:=0
  Field actualFrameIndex:=0
  Field actualFrame:Frame 
  Field previousFrames:= New Stack<Frame>
  
  Public 'Public Methods
  
  Method New()
  End
  
  Method LoadGif:Int(fileName:String)
    
    '-------------GIF Header-------------
    'Load File
    s = New DataStream("monkey://data/" + fileName, False)
    gif = New Gif()
    
    'Header Block
    Header_type = s.ReadString(3)
    Header_version = s.ReadString(3)
    Header_width = s.ReadUInt(2)
    Header_height = s.ReadUInt(2) 
    
    'Logical Screen Descriptor
    Local Header_packedField := HexToBin(DecToHex(s.ReadByte()))
    If Header_packedField[..1] = 1
      Header_hasGlobalColorTable = True
    Else
      Header_hasGlobalColorTable = False
    Endif
    Header_colorResolution = Int(Header_packedField[1..4])
    If Header_packedField[4..5] = 1
      Header_sort = True
    Else
      Header_sort = False
    Endif
    Header_sizeGCT = Pow(2,1+BinToInt(Header_packedField[5..8]))
    Header_backgroundColorIndex = s.ReadUInt(1)
    Header_pixelAspectRatio = (s.ReadUInt(1) + 15) / 64
    
    'Global Color Table
    If Header_hasGlobalColorTable = True
      Header_GCT = New Int[Header_sizeGCT]
      For i=0 Until Header_sizeGCT
        Header_GCT[i]=argb(s.ReadUInt(1),s.ReadUInt(1),s.ReadUInt(1))
      Next
    Endif
    
    
    'Frame Loop
    FrameLoop()

  End
  
  Method GetNumberOfFrames:Int()
    Return numberOfFrames
  End
  
  Method GetComments:Stack<String>()
    Return gif.Ext_Comment_Comments
  End
  
  Method Draw:Void(x:Int, y:Int, rotation:Float=0.0, scaleX:Float=1.0, scaleY:Float=1.0, frame:Int=-1)
    If loaded = False Or frame < -1 Or frame > numberOfFrames
      Return
    Elseif frame = -1
      updates +=1
      PushMatrix()
      
      Translate(x,y)
      Scale(scaleX,scaleY)
      Translate(-x,-y)
      
      Translate(x+Header_width/2,y+Header_height/2)
      Rotate(rotation)
      Translate(-(x+Header_width/2),-(y+Header_height/2))
      
      'Draw previousFrames if have
      For i = 0 To previousFrames.Length-1
        'DrawImage(previousFrames.Get(i).img, (x/scaleX)+previousFrames.Get(i).left, (y/scaleY)+previousFrames.Get(i).top)
        DrawImage(previousFrames.Get(i).img, (x+(previousFrames.Get(i).width/2)+previousFrames.Get(i).left),(y+(previousFrames.Get(i).height/2)+previousFrames.Get(i).top))
      Next
      'Draw actual Frame
      'DrawImage(actualFrame.img, (x/scaleX)+actualFrame.left, (y/scaleY)+actualFrame.top)
      DrawImage(actualFrame.img, x+(actualFrame.width/2)+actualFrame.left,y+(actualFrame.height/2)+actualFrame.top)
  
      'Check if should change frame
      
      PopMatrix()
      
      If updates = actualFrame.graphicControlExtension.delayTime
        updates = 0
        'Is last frame?
        If actualFrameIndex < numberOfFrames-1
          'No
          'Should add to previous frames?
          If actualFrame.graphicControlExtension.disposalMethod = 1
            previousFrames.Push(actualFrame)
          Endif
          actualFrameIndex += 1
        Else
          'Yes
          previousFrames.Clear
          actualFrameIndex = 0
        Endif
        'Update actual frame
        actualFrame = gif.frames.Get(actualFrameIndex)
      Endif
    Else
      DrawSetFrame(x,y,rotation,scaleX,scaleY,frame)
    Endif
  End
  
  Private 'Private Methods
  
  Method DrawSetFrame:Void(x:Int, y:Int, rotation:Float, scaleX:Float, scaleY:Float, frame:Int)
    
    PushMatrix()
      
    Translate(x,y)
    Scale(scaleX,scaleY)
    Translate(-x,-y)
    
    Translate(x+Header_width/2,y+Header_height/2)
    Rotate(rotation)
    Translate(-(x+Header_width/2),-(y+Header_height/2))
    
    If actualFrameIndex = frame
      'Draw previousFrames if have
      For i = 0 To previousFrames.Length-1
        DrawImage(previousFrames.Get(i).img, (x+(previousFrames.Get(i).width/2)+previousFrames.Get(i).left),(y+(previousFrames.Get(i).height/2)+previousFrames.Get(i).top))
      Next
      'Draw actual Frame
      DrawImage(actualFrame.img, x+(actualFrame.width/2)+actualFrame.left,y+(actualFrame.height/2)+actualFrame.top)
    Else
      For i = 0 Until frame
        actualFrame = gif.frames.Get(i)
        actualFrameIndex +=1
        If actualFrame.graphicControlExtension.disposalMethod = 1
          previousFrames.Push(actualFrame)
        Endif
      Next
      actualFrameIndex = frame
      actualFrame = gif.frames.Get(frame)
    Endif
  End
  
  Method FrameLoop:Void()
    If s.ReadByte() = 59 '3B
      Print ">> Loaded <<"
      loaded = True
      numberOfFrames = gif.frames.Length
      actualFrame = gif.frames.Get(0)
    Else
      s.SetPointer(s.GetPointer-1)
      If isApplicationExtension()
        ApplicationExtension()
        FrameLoop()
      Elseif isCommentExtension() 
        CommentExtension()
        FrameLoop()
      Elseif isGraphicControlExtension()
        GraphicsControlExtension()
        FrameLoop()
      Elseif isPlainTextExtension()
        PlainTextExtension()
        FrameLoop()
      Elseif isImageDiscriptor()
        'Create new Frame
        frame=New Frame(tempGraphicControl)
        tempGraphicControl = Null
        gif.AddFrame(frame)
        
        ImageDiscriptor()
        If isLocalColorTable() Then LocalColorTable()
        ImageData()
        FrameLoop()
      Endif 
    Endif
  End 
  
  'GetCode Variables
  Field latestBites:= New Int[8]
  Field latestBitesPointer:Int
  Field subBlockSize:Int
  Field codeInBin:Int[12]
  
  Method GetCode:Int ()
    'Clear
    codeInBin = [0,0,0,0,0,0,0,0,0,0,0,0]
    'Get code
    For i=0 Until codeSize
      codeInBin[11-i] = latestBites[latestBitesPointer]
      latestBitesPointer -= 1
      If latestBitesPointer = -1
        latestBites = DecToBin(s.ReadByte & %11111111)
        latestBitesPointer = 7
        subBlockSize -= 1
        If subBlockSize = 0
          subBlockSize = s.ReadUInt(1)
        Endif
        If subBlockSize = -1
          s.SetPointer(s.GetPointer-1)
        Endif
      Endif
    Next
    Return BinToInt(codeInBin)
  End
  
  'ImageData Variables
  Field pixelsArray:Int[]
  Field pixelsArrayPointer:Int 
  Field codeSize:Int
  Field codeTable:Int[][]
  Field codeTablePointer:Int
  Field oldCode:Int
  Field code:Int
  Field k:Int
  Field color:Int[]
  Field colorLeng:Int
  
  Method ImageData:Void()
    
    frame.LZW_MinimumCodeSize=s.ReadUInt(1)+1

    'Initialize pixel Array
    pixelsArray = New Int[frame.width*frame.height]
    pixelsArrayPointer=0
    
    'Initialize code size
    codeSize = frame.LZW_MinimumCodeSize
    
    'Initialize code streamer
    subBlockSize = s.ReadUInt(1)
    latestBites = DecToBin(s.ReadByte & %11111111)
    subBlockSize -=1
    latestBitesPointer = 7

    'Initialize code table
    codeTable = New Int[4096][]
    If frame.hasLCT = True
      codeTable = InitCodeTable(frame.LCT, frame.sizeLCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
    Else
      codeTable = InitCodeTable(Header_GCT, Header_sizeGCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
    Endif
    
    'Check if first value is equal to "Clear code"(CC)
    If codeTable[GetCode][0] <> CC
      Print "ERROR: First code isn't the Clear code"
    End
    
    'Get first code
    code = GetCode()
    oldCode = code
    pixelsArray[pixelsArrayPointer]=codeTable[code][0]
    pixelsArrayPointer+=1
        
    While True  
      
      'Update code
      code = GetCode
      'Is code in code table?
      If code < codeTablePointer And codeTable[code]
        'Yes
        'Is End of Information (EOI)
        If codeTable[code][0] = EOI Then Exit
        
        'Is Clear Code (CC)
        If codeTable[code][0] = CC    
          'Reset code size
          codeSize = frame.LZW_MinimumCodeSize
          'ReInit code table
          If frame.hasLCT = True
            codeTable = InitCodeTable(frame.LCT, frame.sizeLCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
          Else
            codeTable = InitCodeTable(Header_GCT, Header_sizeGCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
          Endif
          'Update old code
          oldCode = GetCode 
          
          'Add to pixel stack
          For i = 0 Until codeTable[oldCode].Length
            pixelsArray[pixelsArrayPointer]=codeTable[oldCode][i]
            pixelsArrayPointer+=1
          Next
        Else
          'Add to pixel stack
          For i = 0 Until codeTable[code].Length
            pixelsArray[pixelsArrayPointer]=codeTable[code][i]
            pixelsArrayPointer+=1
          Next
          'Add to code table
          k = codeTable[code][0]
          colorLeng = codeTable[oldCode].Length
          color = New Int[colorLeng+1]
          For i = 0 Until colorLeng
            color[i] = codeTable[oldCode][i]
          Next
          color[colorLeng]=k
          codeTable[codeTablePointer]=color
          codeTablePointer +=1
          oldCode = code
        Endif
      Else
        'No
        'Add to pixel stack
        k = codeTable[oldCode][0]
        For i = 0 Until codeTable[oldCode].Length
          pixelsArray[pixelsArrayPointer]=codeTable[oldCode][0]
          pixelsArrayPointer+=1
        Next
        pixelsArray[pixelsArrayPointer]=k
        pixelsArrayPointer+=1
        'Add to code table
        colorLeng = codeTable[oldCode].Length
        color = New Int[colorLeng+1]
        For i = 0 Until colorLeng
          color[i] = codeTable[oldCode][i]
        Next
        color[colorLeng]=k
        codeTable[codeTablePointer]=color
        codeTablePointer +=1
        oldCode = codeTablePointer-1
      Endif
       
      If codeTablePointer-1 = Pow(2,codeSize)-1 And codeSize <12 Then codeSize+=1

    Wend  
              
    'Create the image
    frame.img = CreateImage(frame.width,frame.height)
    frame.img.WritePixels(pixelsArray,0,0,frame.width,frame.height)
    frame.img.SetHandle(frame.img.Width/2,frame.img.Height/2)
    
    pixelsArray=[]
  End
  
  Method isLocalColorTable:Bool()
    If frame.hasLCT
      Return True
    Else
      Return False
    Endif
  End
 
  Method LocalColorTable:Void()
    frame.LCT = New Int[frame.sizeLCT]
    For i = 0 Until frame.sizeLCT
      frame.LCT[i]=argb(s.ReadUInt(1),s.ReadUInt(1),s.ReadUInt(1))
    Next
  End
  
  Method isImageDiscriptor:Bool()
    Local pointer:=s.GetPointer
    If s.ReadByte() = 44 '2C
      Return True
    Else
      s.SetPointer(pointer)
      Return False
    Endif
  End
  
  Method ImageDiscriptor:Void()
    frame.left = s.ReadUInt(2) 
    frame.top = s.ReadUInt(2) 
    frame.width = s.ReadUInt(2) 
    frame.height = s.ReadUInt(2) 
    Local packedField := HexToBin(DecToHex(s.ReadByte()))
    If packedField <> "00000000"
      If packedField[..1] = 1 Then frame.hasLCT = True
      If packedField[1..2] = 1 Then frame.interlace = True
      If packedField[2..3] = 1 Then frame.sort = True
      frame.sizeLCT = Pow(2,1+BinToInt(packedField[5..8]))
    Endif
  End
  
  Method isGraphicControlExtension:Bool()
    Local pointer:=s.GetPointer
    If s.ReadByte() = 33 And s.ReadByte() = -7
      Return True
    Else
      s.SetPointer(pointer)
      Return False
    Endif
  End
  
  Method GraphicsControlExtension:Void()
    s.ReadByte() 'Skip Byte size
    tempGraphicControl = New GraphicControlExtension()
    Local packedField := HexToBin(DecToHex(s.ReadByte()))
    tempGraphicControl.disposalMethod = BinToInt(packedField[3..6])
    If packedField[6..7] = 1
      tempGraphicControl.userInput = True
    Else
      tempGraphicControl.userInput = False
    Endif
    If packedField[7..8] = 1
      tempGraphicControl.transparentColor = True
    Else
      tempGraphicControl.transparentColor = False
    Endif
    If UpdateRate <> 0
      tempGraphicControl.delayTime = UpdateRate*(s.ReadUInt(2)/100.0)
    Else
      Print "ERROR: Please set the UpdateRate"
    Endif
    tempGraphicControl.transparentColorIndex = s.ReadUInt(1)
    If s.ReadByte() <> 0 Then Print "ERROR: Graphics Control Extension Problem"
  End
  
  Method isPlainTextExtension:Bool()
    Local pointer:=s.GetPointer
    If s.ReadByte() = 33 And s.ReadByte() = 1
      Return True
    Else
      s.SetPointer(pointer)
      Return False
    Endif
  End

  Method PlainTextExtension:Void()
    s.SetPointer(s.GetPointer()+ BinToInt(HexToBin(s.ReadByte())) ) 'TODO - I'm skipping for now
    While s.ReadByte() <> 0
    Wend
  End
  
  Method isApplicationExtension:Bool()
    Local pointer:=s.GetPointer
    If s.ReadByte() = 33 And s.ReadByte() = -1
      Return True
    Else
      s.SetPointer(pointer)
      Return False
    Endif
  End
  
  Method ApplicationExtension:Void()
    gif.Ext_Application = True
    If s.ReadByte <> 11 Then Print "ERROR: Application Extension Problem"
    gif.Ext_Application_Identifier = s.ReadString(8)
    gif.Ext_Application_Code = s.ReadString(3)
    While BinToInt(HexToBin(s.ReadByte())) <> 0
      s.SetPointer(s.GetPointer-1)
      s.SetPointer(s.GetPointer()+ BinToInt(HexToBin(s.ReadByte()))) 'TODO - I'm skipping for now
    Wend
    If s.ReadByte() <> 0 Then Print "ERROR: Application Extension Problem"
  End
 
  Method isCommentExtension:Bool()
    Local pointer:=s.GetPointer
    If s.ReadByte() = 33 And s.ReadByte() = -2
      Return True
    Else
      s.SetPointer(pointer)
      Return False
    Endif
  End
  
  Method CommentExtension:Void()
    gif.Ext_Comment = True
    gif.Ext_Comment_Comments = New Stack<String>
    While BinToInt(HexToBin(s.ReadByte())) <> 0
      s.SetPointer(s.GetPointer-1)
      gif.Ext_Comment_Comments.Push(s.ReadString(s.ReadByte()))
    Wend
  End
  
  Method GetFirstIndex:String(indexes:Int[])
    Local result:String
    For i = 0 Until indexes.Length
      If indexes[i] = " " Then Exit
      result += indexes[i]
    End
    Return result
  End
 
  Method InitCodeTable:Int[][](colorTable:Int[], size:Int, transparentColor:Bool, transparentColorIndex:Int)
    codeTable = New Int[4096][]
    codeTablePointer = 0
    Local color:Int[]
    For Local i:=0 Until size
      color = New Int[1]
      If transparentColor = False
        color[0]=colorTable[i]
      Else
        If transparentColorIndex <> i 
          color[0]=colorTable[i]
        Else
          color[0]=argb(0,0,0,0)'Transparent color
        End
      End
      codeTable[codeTablePointer]=color
      codeTablePointer +=1
    Next
    'Add Clear Code
    color = New Int[1]
    color[0]=CC
    codeTable[codeTablePointer]=color
    codeTablePointer +=1
    'Add End of Information code
    color = New Int[1]
    color[0]=EOI
    codeTable[codeTablePointer]=color
    codeTablePointer +=1
    
    Return codeTable
  End
 
End

Class Gif
  '------ApplicationExtension------
  Field Ext_Application:=False
  Field Ext_Application_Identifier:String
  Field Ext_Application_Code:String

  '------CommentExtension------
  Field Ext_Comment:=False
  Field Ext_Comment_Comments:Stack<String>
  
  '------Frames------
  Field frames:Stack<Frame>
  
  Method New()  
    frames = New Stack<Frame>
  End
  
  Method AddFrame:Void(frame:Frame)
    frames.Push(frame)
  End
End

Class Frame   
  '-----Image Descriptor-----
  Field left:Int
  Field top:Int
  Field width:Int
  Field height:Int
  Field hasLCT:=False 'Has Local Color Table?
  Field interlace:=False
  Field sort:=False
  Field sizeLCT:=0 'Size of Local Color Table
  
  '-----Graphic Control Extension-----
  Field graphicControlExtension:GraphicControlExtension
  
  '-----Local Color Table-----
  Field LCT:Int[] 'Local color table
  
  '-----Image Data-----
  Field LZW_MinimumCodeSize:Int
  
  'Image
  Field img:Image
  
  Method New(graphicControlExtension:GraphicControlExtension)
    Self.graphicControlExtension = graphicControlExtension
  End
  
End

Class GraphicControlExtension
  Field disposalMethod:Int
  Field userInput:Bool
  Field transparentColor:Bool
  Field delayTime:Float
  Field transparentColorIndex:Int
  
  Method New()
  End
End

'------------------------ TODO --------------------------------
'Help functions and methods, I should organize this

Function argb:Int(r:Int, g:Int, b:Int ,alpha:Int=255)
  Return (alpha Shl 24) | (r Shl 16) | (g Shl 8) | b                      
End 

Function DecToHex:String(dec:Int)
  'Local r%=dec, s%, p%=32, n:Int[p/4+1]
  Local r%=dec, s%, p%=8, n:Int[p/4+1]

	While (p>0)
		
		s = (r&$f)+48
		If s>57 Then s+=7
		
		p-=4
		n[p Shr 2] = s
		r = r Shr 4
		 
	Wend
  
	Return String.FromChars(n)
End

Function HexToBin:String(hex:String)
  Local bin:String
  For Local i:=0 Until hex.Length
    Select hex[i..i+1]
    Case "0"; bin += "0000"
    Case "1"; bin += "0001"
    Case "2"; bin += "0010"
    Case "3"; bin += "0011"
    Case "4"; bin += "0100"
    Case "5"; bin += "0101"
    Case "6"; bin += "0110"
    Case "7"; bin += "0111"
    Case "8"; bin += "1000"
    Case "9"; bin += "1001"
    Case "A"; bin += "1010"
    Case "B"; bin += "1011"
    Case "C"; bin += "1100"
    Case "D"; bin += "1101"
    Case "E"; bin += "1110"
    Case "F"; bin += "1111"
    End
  Next
  Return bin
End

Function HexToBin_Array:Int[](hex:String)
  Local bin:= New Int[hex.Length*4]
  Local binPointer:=0
  For Local i:=0 Until hex.Length
    Select hex[i..i+1]
    Case "0"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0000
    Case "1"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0001
    Case "2"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0010
    Case "3"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0011
    Case "4"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0100
    Case "5"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0101
    Case "6"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0110
    Case "7"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0111
    Case "8"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1000
    Case "9"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1001
    Case "A"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1010
    Case "B"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1011
    Case "C"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1100
    Case "D"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1101
    Case "E"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1110
    Case "F"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1111
    End
  Next
  Return bin
End

Function BinToInt:Int(bin:String)
  Local dec:Int
  For Local i:int = 0 Until bin.Length
    dec += Int(bin[bin.Length - i - 1 .. bin.Length - i]) * Pow(2, i)
  Next
  Return dec
End

Function BinToInt:Int(bin:Int[])
  Local dec:Int
  For Local i:int = 0 Until 12
    dec += bin[11 - i] * Pow(2, i)
  Next
  Return dec
End

Function DecToBin:Int[](dec:Int)
  Local result:Int
  Local multiplier:Int
  Local residue:Int
  Local resultArr:Int[]=[0,0,0,0,0,0,0,0]
  Local resultArrPointer:Int
  multiplier = 1
  While (dec > 0)
    residue = dec Mod 2
    result = result + residue * multiplier
    dec = dec / 2
    multiplier = multiplier * 10
  Wend
  resultArrPointer = 7
  While result > 0
    resultArr[resultArrPointer]=result Mod 10
    result/=10
    resultArrPointer-=1
  Wend
 Return resultArr
End Function 

Class DataStream
	'Byte = 8 Bits
	'U = Unsigned (i.e. ReadUInt = ReadUnsignedInt)
	'ReadInt(ByteCount) - I type Int and mean number - by using adjusting 'ByteCount' it can technically be a byte(1), short(2) or Long(4) etc
	Field Buffer:DataBuffer
	Field Pointer
	Field BigEndian:Bool
	
	'Create New Datastream
	Method New(Path:String, BigEndianFormat:Bool = True)
		Buffer = DataBuffer.Load(Path)
		Pointer = 0
		BigEndian = BigEndianFormat
	End Method
	
	'Sets the Datastream pointer location (offset from strat of file in bytes)
	Method SetPointer(Offset)
		Pointer = Offset
	End Method
	
	'Sets the Datastream pointer location (offset from strat of file in bytes)
	Method GetPointer()
		Return Pointer
	End Method
	
	'Read Methods
	Method ReadInt(ByteCount)
		Pointer = Pointer + ByteCount
		If Not BigEndian Then Return CalculateBits(ChangeEndian(BytesToArr(Pointer - ByteCount, ByteCount)))
		Return CalculateBits(BytesToArr(Pointer - ByteCount, ByteCount))
	End Method
	
	Method ReadUInt(ByteCount)
		Pointer = Pointer + ByteCount
		If Not BigEndian Then Return CalculateUBits(ChangeEndian(BytesToArr(Pointer - ByteCount, ByteCount)))
		Return CalculateUBits(BytesToArr(Pointer - ByteCount, ByteCount))
	End Method
	
	Method ReadFixed32:Float()
		Return Float(ReadInt(2) + "." + ReadInt(2))
	End Method
	
	Method ReadString:String(ByteCount)
		Pointer = Pointer + ByteCount
		Return Buffer.PeekString(Pointer - ByteCount, ByteCount)
	End Method
    
	Method ReadByte:Int()
    Pointer += 1
    Return Buffer.PeekByte(Pointer - 1)
	End Method
	
	Method ReadBits:Int[] (ByteCount)
		Local Str:Int[] = BytesToArr(Pointer, ByteCount)
		Pointer = Pointer + ByteCount
		If Not BigEndian Then Str = ChangeEndian(Str)
		Local temp
		For Local i = 0 Until Str.Length / 2
			temp = Str[i]
			Str[i] = Str[Str.Length - i - 1]
			Str[Str.Length - i - 1] = temp
		Next
		Return Str
	End Method
	
	'Peek Methods
	Method PeekInt(ByteCount, Address)
		If Not BigEndian Then Return CalculateBits(ChangeEndian(BytesToArr(Address, ByteCount)))
		Return CalculateBits(BytesToArr(Address, ByteCount))
	End Method
	Method PeekUInt(ByteCount, Address)
		If Not BigEndian Then CalculateUBits(ChangeEndian(BytesToArr(Address, ByteCount)))
		Return CalculateUBits(BytesToArr(Address, ByteCount))
	End Method
	Method PeekFixed32:Float(Address)
		Return Float(PeekInt(2, Address) + "." + PeekInt(2, Address + 2))
	End Method
	Method PeekString:String(ByteCount, Address)
		Return Buffer.PeekString(Address, ByteCount)
	End Method
	Method PeekBits:Int[] (ByteCount, Address)
		Local Str:Int[] = BytesToArr(Address, ByteCount)
		If Not BigEndian Then Str = ChangeEndian(Str)
		'reverse str
		Local temp
		For Local i = 0 Until Str.Length / 2
			temp = Str[i]
			Str[i] = Str[Str.Length - i - 1]
			Str[Str.Length - i - 1] = temp
		Next
		Return Str
	End Method
	
	'Converts Bit array to String - Helpfull for debug	
	Function ToString:String(Bits:Int[])
		Local Rtn:String
		For Local i = 0 To Bits.Length - 1
			Rtn = Rtn + Bits[i]
		Next
		Return Rtn
	End Function
	
	Function ChangeEndian:Int[] (BitString:Int[])
		If BitString.Length < 16 Then Return BitString
		Local t
		For Local b = 0 To(BitString.Length - 1) / 2 Step 8
			For Local i = 0 To 7
				t = BitString[b + i]
				BitString[b + i] = BitString[BitString.Length - 8 - b + i]
				BitString[BitString.Length - 8 - b + i] = t
			Next
		Next
		Return BitString
	End Function
	Method BytesToArr:Int[] (Address, Count)
		Local Str:Int[Count * 8], Counter = 0
		For Local i = 0 To Count - 1
			Local Byt:Int[] = ByteToArr(Address + i)
			For Local c = 0 To 7
				Str[Counter] = Byt[c]
				Counter = Counter + 1
			Next
		Next
		Return Str
	End Method	
	Method ByteToArr:Int[] (Address)
		Local I:Int = Buffer.PeekByte(Address)
		Local Str:Int[8]
		'If I = Positive
		If I > - 1 Then
			'Create Bits
			Local D = 128, Counter = 0
			While I > 0
				If I >= D Then
					Str[Counter] = 1
					I = I - D
				Else
					Str[Counter] = 0
				End If
				D = D / 2
				Counter = Counter + 1
			Wend
			'Pad Out
			While Counter < 8
				Str[Counter] = 0
				Counter = Counter + 1
			Wend
			Return Str
		End If
		
		'If I = Negative

		I = I * -1
		'Create Bits (and Flip)
		Local D = 128, Counter = 0
		While I > 0
			If I >= D Then
				Str[Counter] = 1
				I = I - D
			Else
				Str[Counter] = 0
			End If
			D = D / 2
			Counter = Counter + 1
		Wend
		'Pad Out
		While Str.Length < 8
			Str[Counter] = 0
			Counter = Counter + 1
		Wend
		'Flip
		For Local i = 7 To 0 Step - 1
			If Str[i] = 0 Then
				Str[i] = 1
			Else
				Str[i] = 0
			End If
		Next
		'Add 1
		For Local i = 7 To 0 Step - 1
			If Str[i] = 0 Then
				Str[i] = 1
				Exit
			Else
				Str[i] = 0
			End If
		Next
		Return Str
	End Method

	Function CalculateUBits(BitString:Int[])
		Local Rtn:Int, D:Int = 1
		For Local i =  BitString.Length - 1 To 0 Step -1
			If BitString[i] = 1 Then
				Rtn = Rtn + D
			End If
			D = D * 2
		Next
		Return Rtn
	End Function
	Function CalculateBits(BitString:Int[])
		'If Positive
		If BitString[0] = 0 Then
			Local Rtn:Int, D:Int = 1
			For Local i = BitString.Length - 1 To 0 Step - 1
				If BitString[i] = 1 Then
					Rtn = Rtn + D
				End If
				D = D * 2
			Next
			Return Rtn
		End If
		
		'===If Negative
		'Flip Bits and into array
		For Local i = 0 To BitString.Length - 1
			If BitString[i] = 0 Then
				BitString[i] = 1
			Else
				BitString[i] = 0
			End If
		Next
		'Add 1
		For Local i = BitString.Length - 1 To 0 Step - 1
			If BitString[i] = 0 Then
				BitString[i] = 1
				Exit
			Else
				BitString[i] = 0
			End If
		Next
		'Add Up
		Local Rtn:Int, D:Int = 1
		For Local i = BitString.Length - 1 To 0 Step - 1
			If BitString[i] = 1 Then
				Rtn = Rtn + D
			End If
			D = D * 2
		Next
		Return Rtn*-1
		
	End Function
	
End Class

#rem
'/*
'* Copyright (c) 2011, Damian Sinclair
'*
'* All rights reserved.
'* Redistribution and use in source and binary forms, with or without
'* modification, are permitted provided that the following conditions are met:
'*
'*   - Redistributions of source code must retain the above copyright
'*     notice, this list of conditions and the following disclaimer.
'*   - Redistributions in binary form must reproduce the above copyright
'*     notice, this list of conditions and the following disclaimer in the
'*     documentation and/or other materials provided with the distribution.
'*
'* THIS SOFTWARE IS PROVIDED BY THE SQUISH PROJECT CONTRIBUTORS "AS IS" AND
'* ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
'* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
'* DISCLAIMED. IN NO EVENT SHALL THE SQUISH PROJECT CONTRIBUTORS BE LIABLE
'* FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
'* DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
'* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
'* CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
'* LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
'* OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
'* DAMAGE.
'*/
#end

Class ByteArray
    Field capacity:Int = 10
    Field arr:Int[]
    Field arrLength:Int = 0
    Field byteLength:Int = 0
    
    Method New()
        arr = New Int[capacity]
    End
    
    Method New(copy:ByteArray)
        Self.capacity = copy.capacity
        Self.arr = New Int[capacity]
        'This is actually faster than using the array slice copy
        'presumably because that uses reflection
        For Local i:Int = 0 Until copy.arrLength
            arr[i] = copy.arr[i]
        End
        arrLength = copy.arrLength
        byteLength = copy.byteLength
        If byteLength Mod 4 > 0
            arr[arrLength] = copy.arr[arrLength]
        End
    End
    
    Method New(s:String)
        capacity = s.Length/2+1
        arr = New Int[capacity]
        
        For Local i:Int = 0 Until s.Length
            Append(((s[i]&$0000FF00) Shr 8)&$FF)
            Append(s[i]&$FF)
        End
    End
    
    Method New(val:Int)
        arr = New Int[capacity]
        Append(val)    
    End
    
    Method Length:Int() Property
        Return byteLength    
    End
    
    Method Append:Void( arr:ByteArray )
        For Local i:Int = 0 Until arr.Length
            Append(arr.GetByte(i))
        End     
    End
    
    Method Append:Void(val:Int)
        If arrLength = capacity
            capacity *= 2
            arr = arr.Resize(capacity)
        End
        Local shift:Int = (3 - (byteLength Mod 4)) * 8
        arr[arrLength] = arr[arrLength]|((val&$FF) Shl shift)
        byteLength += 1
        If byteLength Mod 4 = 0
            arrLength += 1
        End
    End   
    
    Method Add:ByteArray(val:Int)
        Local copy:ByteArray = New ByteArray(Self)
        copy.Append(val)
        Return copy
    End
    
    Method CompareTo:Int( other:ByteArray )
        If other.byteLength <> Self.byteLength
            Return Self.byteLength - other.byteLength
        End
        
        Local len:Int = arrLength
        If byteLength Mod 4 > 0
            len += 1
        End
        Local ind:Int = 0
        
        While ind < byteLength
            Local si:Int = Self.GetByte(ind)
            Local oi:Int = other.GetByte(ind)
            If oi <> si
                Return si - oi
            End
            ind += 1
        End
        
        Return 0
    End
    
    Method PrintInts:Void()
        Local s:String
        For Local i:Int = 0 Until Length Step 2
            s += String((GetByte(i) Shl 8)|GetByte(i+1)) + ","
        End
        
        Print s
    End
    
    Method PrintBytes:Void()
        Local s:String = "["
        For Local i:Int = 0 Until Length
            s += GetByte(i) + ","
        End
        s += "]"
        Print s
    End
    
    Method GetByte:Int( index:Int )
        Local shift:Int = (3 - index Mod 4) Shl 3
        Local ret:Int = ((arr[index Shr 2] & ($FF Shl shift)) Shr shift)&$FF
        Return ret
    End
    
    Method ToString:String()
        Local strArr:String[]
        If byteLength Mod 4 > 0 
            If byteLength Mod 4 > 2 
                strArr = New String[arrLength*2+2]
            Else  
                strArr = New String[arrLength*2+1]
            End
        Else
            strArr = New String[arrLength*2]
        End
        For Local i:Int = 0 Until arrLength
            strArr[i*2] = String.FromChar((arr[i]&$FFFF0000) Shr 16)
            strArr[i*2+1] = String.FromChar(arr[i]&$0000FFFF)            
        End
        Local remBytes:Int = byteLength - arrLength*4
        If remBytes > 0
            strArr[arrLength*2] = String.FromChar(((arr[arrLength]&$FFFF0000) Shr 16) & $FFFF)
            If remBytes > 2
                strArr[arrLength*2+1] = String.FromChar(arr[arrLength]&$0000FFFF)
            End
        End
        Return "".Join(strArr)
    End
    
    Method ObjectEnumerator:ByteArrayObjectEnumerator()
        Return New ByteArrayObjectEnumerator(arr,byteLength)
    End
End

Class ByteArrayObjectEnumerator
	Field arr:Int[]
    Field byteLength:Int
    Field currByte:Int = 0
    
    Method New( arr:Int[], byteLength:Int)
		Self.arr = arr
        Self.byteLength = byteLength
	End

	Method HasNext()
		Return currByte < byteLength
	End
	
	Method NextObject:IntObject()
        Local ind:Int = currByte/4
        Local shift:Int = (3 - currByte Mod 4) * 8
        currByte += 1
		Return New IntObject(((arr[ind] & $FF) Shl shift) Shr shift)
	End
End

Class ByteArrayMap<V> Extends Map<ByteArray,V>

	Method Compare( lhs:ByteArray,rhs:ByteArray )
		Return lhs.CompareTo(rhs)
	End

End

#rem
' summary:This class provides string compression and decompression functions based on the LZW
' algorithm. It is based on implementations found at http://rosettacode.org/wiki/LZW_compression
#end
Class LZW
    
    Private
    
    Global compressDict:ByteArrayMap<IntObject> = New ByteArrayMap<IntObject>()
    Global uncompressDict:ByteArray[] = []
    
    Public
    
#rem
    summary: Takes an input string and returns the LZW compressed version
#end
    Function CompressString:String(input:String)
        Local dictSize:Int = 256 + avoidZero
        compressDict.Clear()
        
        For Local i:Int = avoidZero Until dictSize
            Local ba:ByteArray = New ByteArray()
            ba.Append(i-avoidZero)
            compressDict.Set(ba, i)
        End
        'Add 0 combinations
        For Local i:Int = 0 Until dictSize
            Local ba:ByteArray = New ByteArray()
            ba.Append(i)
            ba.Append(0)
            compressDict.Set(ba, dictSize+i)
            ba = New ByteArray()
            ba.Append(0)
            ba.Append(i)
            compressDict.Set(ba, dictSize+256+i)
        End
        
        dictSize += 512
        
        Local w:ByteArray = New ByteArray()
        Local ia:ByteArray = New ByteArray(input)
        Local result:String[] = New String[ia.Length+1]
        
        For Local i:Int = 0 Until ia.Length
            Local byte:Int = ia.GetByte(i)
            Local wc:ByteArray = w.Add(byte)
                   
            If (compressDict.Contains(wc))
                w = wc
            Else
                Local code:Int = compressDict.Get(w)
                result[i] = String.FromChar(code)
                ' Add wc to the dictionary.
                compressDict.Set(wc, dictSize)
                dictSize += 1
                w = New ByteArray(byte)
            End
        End
        ' Output the code for w.
        If w.Length() > 0
            result[ia.Length] = String.FromChar(compressDict.Get(w))
        End
        
        Return "".Join(result)
        
    End
    
#rem
    summary: Takes a string compressed with CompressString and returns the uncompressed version.
    Set discardDict to True to recover the memory used for the decompression dictionary
#end
    Const avoidZero:Int = 1
    Function DecompressString:String(compressed:String, discardDict:Bool = False)
    
        Local dictSize:Int = 256 + avoidZero
                
        'Trading memory for performance here by using an array rather than a map
        If uncompressDict.Length = 0
            uncompressDict = New ByteArray[65536]
            For Local i:Int = avoidZero Until dictSize
                uncompressDict[i] = New ByteArray(i-avoidZero)
            End 
            'Add 0 combinations
            For Local i:Int = 0 Until dictSize
                Local ba:ByteArray = New ByteArray()
                ba.Append(i)
                ba.Append(0)
                uncompressDict[dictSize+i] = ba
                
                ba = New ByteArray()
                ba.Append(0)
                ba.Append(i)
                uncompressDict[dictSize+256+i] = ba
            End
        
        End
        
        dictSize += 512
        
        Local dictionary:ByteArray[] = uncompressDict[..]
        Local w:ByteArray = New ByteArray()
        Local sa:ByteArray = New ByteArray()
        
        Local i:Int = 0
        While i < compressed.Length
            Local k:Int = compressed[i]
            Local entry:ByteArray
            
            If dictionary[k] And dictionary[k].Length > 0
                entry = dictionary[k]
            ElseIf k = dictSize
                entry = w.Add(w.GetByte(0))
            Else
                Error "LZW - unknown dictionary key: " + k
            End
            sa.Append( entry )
            
            If w.Length > 0
                'Add w+entry[0] to the dictionary.
                dictionary[dictSize] = w.Add(entry.GetByte(0))
                dictSize += 1
            End
            w = entry
            i += 1
        End
        
        If discardDict
            uncompressDict = []
        End
        Return sa.ToString()
    End
 End