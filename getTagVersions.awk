# Erzeugt output des Filenamen mit gefundenen Tags
#  Grundlage ist ein mit 'cvs status -v' erzeugtes file
#
# Parameter:
#  sep    : eigener separator möglich anstelle von Space " "
#  width  : Breite der ersten Spalte sonst so breit wie nötig
#
# Beispiele von Ausgabetexten
# BPC386WIN.HX v1_85 (1.1)
# F_STRING.OBJ vx_xx (1.1)
# L386.obj v1_00 (1.1)
# gugus v1_00+ (1.2)
#
function isort(A, n, qq,   i, j, hold, prcnt)
{
  if (qq)
  {
    prcnt = sprintf("%d",(n / 10)) + 0;
    if (debug) print "#6#n: ",n,"prcnt: ",prcnt;
    printf(" sorting taglist ");
  }
  if (n == 1)
  {
    A[1] = A[0];
    A[0] = "";
  }
  else
  {
    for(i = 2; i <= n; i++)
    {
      hold = A[j = i];
      while(A[j-1] > hold)
      {
        j--;
        A[j+1] = A[j];
      }
      A[j] = hold;
      if (qq && i%prcnt == 0)
        printf(".");
    }      
  }
  if (qq)
    printf("\n");
}
function printARRAY(ARRAY,  TF,tmptag, tag, fname, tagfname)
{                                 
  tmptag = "";
  for ( tagfname in ARRAY )
  {                                                
    split(tagfname,TF,SUBSEP);
    tag = TF[1];
    fname = TF[2];
    if (tmptag != tag)
    {
      tmptag = tag;
      print tag > outfile;
    }
    print "",fname,"("ARRAY[tag,fname]")";
  }
}
BEGIN {
  RS="==================================================================="; 
  delete NAMEARR; 
  if (!outfile)
    outfile = "tags.txt";
  if (sep)
    OFS=sep;
  nacnt = 0;
}
{                                                                                            
  nsp = split($0,LINEARR,"\r?\n");
  delete VERTAG;
  delete TAGARR;
  if (nsp > 0)
  {
    if (debug) print "#0#nsp"nsp;
    # line 2  : contains filename; if prefix 'no file 'FILENAME then don't process entries
      # structure of filenameline: "File: (no file )?<Filename> *\tStatus: <state>"
    # line 4  : contains working revision
    # line 11+: contains Tag entries
    if (debug) print "#9#filenameline:#"LINEARR[2]"#";
    if (!match(LINEARR[2],"File: no file "))
    {                      
      split(LINEARR[2],ARR,"\t");
      match(ARR[1],"^File: ");
      if (debug) print "#10#"ARR[1]"#";
      fnstart = RSTART + RLENGTH;
      if (debug) print "#11#"RSTART","RLENGTH;
      match(ARR[1]," *$");
      if (debug) print "#12#"RSTART","RLENGTH;
      fnlen = RSTART - fnstart;
      fname = substr(ARR[1],fnstart,fnlen);
      if (debug) print "#1#name : #"fname"#";
      split(LINEARR[4],ARR,"\t");
      wrev = ARR[2];
      if (debug) print "#2#wver : "wrev;
      tcnt = 0;
      if (debug) print "#3#"nsp > outfile;
      for (i=11;i < nsp; i++)
      {
        # process tag entries and fill them into VERTAG array
        split(LINEARR[i], ARR, "\t");
        split(ARR[3], VER,"[ \)]");
        split(ARR[2], TAG);
        tag = TAG[1];
        if (debug) print "#7#tagline: #"ARR[2]"#";
        if (debug) print "#8#tag: #"tag"#";
        if (tag != "" && !match(ARR[2],"No Tags Exist"))
        {
          VERTAG[VER[2]] = tag;
          TAGARR[tag] = VER[2];
          TAGARR[tcnt++] = tag OFS VER[2];
          if (debug) print "#4#ver  : "tcnt"#"VER[2]"#"tag"#";
        }
      }
      if (tcnt > 0) isort(TAGARR,tcnt,0);
                              
      if (!longfmt)
        print fname > outfile;
      if (debug) print "#5#Anzahl Tags:"tcnt;      
      for (i=1; i <= tcnt; i++)
      {              
        if (!match(TAGARR[i],"^[ \t]*$"))
        {                             
          split(TAGARR[i],A,OFS);
          NAMEARR[nacnt++] = A[1] SUBSEP fname SUBSEP A[2];
  
          if (longfmt)
            outline = A[1] OFS fname OFS "("A[2]")";
          else
          {       
            outline = " " A[1] OFS "("A[2]")";
            if (width)
            {                     
              format= "%" width "s";
              outline = sprintf(format, outline);
            }
          }
          print outline > outfile;
        }
      }
    }
  }
}
END { print "sorting names ->";
  isort(NAMEARR,nacnt,1);
  print "<- sorting done";
  currtag = "";
  outf2 = "tags2.txt";
  for (i=1; i <= nacnt; i++)
  { 
    split(NAMEARR[i],B,SUBSEP);
    if (currtag != B[1])
    {
      currtag = B[1];
      print currtag > outf2;
    }
    print OFS B[2] OFS "("B[3]")" > outf2;
  }
}
