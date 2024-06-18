using Godot;
using System;
using System.IO;
using System.Collections.Generic;
using System.Linq;


[GlobalClass]
public partial class PDFWord : GodotObject
{
    public Godot.Collections.Array<PDFLetter> GDLetters = new();

    public Vector2 WordPos = new();
    public Vector2 WordBBox = new();
    // TODO; Implement GetWordBBox which constructs the BBox from the size and pos of its letters

    public string GetWordString()
    {
        string newString = "";
        foreach (PDFLetter letter in GDLetters)
        {
            newString += letter.Str;

        }
        return newString;
    }

    private Vector2 GetWordBBoxFromLetters()
    {
        // TODO: Implement
        return new Vector2();
    }
}