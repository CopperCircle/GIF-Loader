#IMAGE_FILES="*.png|*.jpg|*.gif|*.bmp"

Import mojo
Import gifreader

Function Main:Int()
	New MyApp
	Return 1
End

Class MyApp Extends App
	Field gifReader:GifReader
	Field numberOfFrames:Int
	Field comments:Stack<String>
	Field startLoad:Float
	Field endLoad:Float
	
	Method OnCreate:Int()
		SetUpdateRate(60)
		gifReader = New GifReader
		startLoad = Millisecs
		gifReader.LoadGif("gif8.gif")
		endLoad = Millisecs
		numberOfFrames = gifReader.GetNumberOfFrames()
		comments = gifReader.GetComments()
	  
		Return 0
	End
	
	Field i:=0
	Method OnRender:Int()
		Cls 0,0,255
		DrawText("Load Time: "+(endLoad-startLoad)+" Millisecs / "+(endLoad-startLoad)/1000+" Secs" , 50 , 35)
		DrawText("Number of Frames: "+numberOfFrames , 50 , 50)
		If comments And comments.Length > 0
			For Local i:=0 Until comments.Length
				DrawText(comments.Get(i) , 50 , 65+(i*15))
			Next
		Endif
		i+=4
		gifReader.Draw(50, 100, 0, 0.5, 0.5)
		'gifReader.Draw(50,100,0,2,2)
		Return 1
	End
	
	Method OnUpdate:Int()
		Return 1
	End
End