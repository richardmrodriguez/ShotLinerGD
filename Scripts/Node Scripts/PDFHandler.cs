using Godot;
using Godot.NativeInterop;
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;
using System.Linq.Expressions;

// PDFPig 0.1.8
using UglyToad.PdfPig;
using UglyToad.PdfPig.Content;
using UglyToad.PdfPig.Graphics.Operations.TextState;
using UglyToad.PdfPig.DocumentLayoutAnalysis.PageSegmenter;
using PigDocAnalysis = UglyToad.PdfPig.DocumentLayoutAnalysis;
using UglyToad.PdfPig.Core;
public partial class PDFHandler : Node
{

	public string DocFilePath = "";

	public byte[] DocFileBytes;


	public override void _Ready()
	{

	}



	public string GetStringFromPDFPage(string PDFDocPath)
	{


		using (PdfDocument document = PdfDocument.Open(PDFDocPath))
		{
			Page page = document.GetPage(2);

			IEnumerable<Word> words = page.GetWords();
			string test_string = "";
			for (int i = 0; i < 11; i++)
			{
				test_string += words.ElementAt(i) + " ";
			}

			return test_string;
		}
	}

	public PDFDocGD GetDocGD(string filepath)
	{
		PDFDocGD docGD = new();
		using (PdfDocument document = PdfDocument.Open(filepath))
		{
			foreach (Page page in document.GetPages())
			{
				//GD.Print(page.Width, " | ", page.Height);
				PDFPage NewPage = new();
				IEnumerable<Word> words = page.GetWords();

				Godot.Collections.Array<PDFLineFN> NewLines = GetLinesFromPageWords(words);
				NewPage.PDFLines = NewLines;
				docGD.PDFPages.Add(NewPage);

			}


		}


		return docGD;
	}


	private Godot.Collections.Array<PDFLineFN> GetLinesFromPageWords(IEnumerable<Word> words)
	{
		Godot.Collections.Array<PDFLineFN> NewLinesArr = new();
		Word someWord = words.ElementAt(0);
		Letter someLetter = someWord.Letters.ElementAt(0);

		var rXYWithParams = new RecursiveXYCut(new RecursiveXYCut.RecursiveXYCutOptions()
		{

			// Using RecursiveXYCut, setting the Minimum Width to the Page Width or larger 
			// results in getting each horizontal line in the correct order. Because A4 scripts are narrower,
			// I think it's probably fine to just keep this magic number of 86 characters wide.
			MinimumWidth = someLetter.Width * 86,
			//DominantFontWidthFunc = letters => letters.Select(l => l.GlyphRectangle.Width).Average(),
			//DominantFontHeightFunc = letters => letters.Select(l => l.GlyphRectangle.Height).Average()
		}
		);
		var blocks = rXYWithParams.GetBlocks(words);

		foreach (var block in blocks)
		{
			//GD.Print("Here's a block");
			foreach (PigDocAnalysis.TextLine line in block.TextLines)
			{
				//GD.Print("Here's a textline");
				PDFLineFN NewLine = new();
				Godot.Collections.Array<PDFWord> NewWords = new();
				foreach (Word word in line.Words)
				{
					PDFWord NewWord = new();
					foreach (Letter l in word.Letters)
					{
						//GD.Print("Here's a letter");
						PDFLetter NewLetter = new()
						{
							Str = l.Value,
							Location = new Vector2(
							(float)l.Location.X,
							(float)l.Location.Y),
							GlyphRect = new Vector2(
							(float)l.GlyphRectangle.BottomLeft.X,
							(float)l.GlyphRectangle.BottomLeft.Y),
							FontSize = (float)l.FontSize,
							PointSize = (float)l.PointSize
						};
						NewWord.GDLetters.Add(new PDFLetter());
						//GD.Print("Added a bullshit letter");
						NewWord.GDLetters.Add(NewLetter);
						//GD.Print("Added a letter!");
					}
					NewLine.PDFWords.Add(NewWord);
				}
				NewLinesArr.Add(NewLine);
			}

		}
		return NewLinesArr;
	}
}
