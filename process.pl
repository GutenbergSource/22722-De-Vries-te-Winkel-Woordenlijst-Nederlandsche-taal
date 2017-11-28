# process.pl -- Generate a number of files from the wordlist .TEI file.
#
# Usage: process.pl [-t] < Woordenlijst1914-1.0.tei

use utf8;
binmode(STDOUT, ":utf8");
use open ':utf8';

require Encode;
use Unicode::Normalize;

###use Lingua::Identify qw/langof/;
use SgmlSupport qw/getAttrVal sgml2utf/;
use LanguageNames qw/getLanguage/;

if ($ARGV[0] eq "-t") {
    testTagPartOfSpeech();
    exit;
}

main();


sub main() {
    open(FULLFILE, "> Woordenlijst1914-full-1.0.tei") || die("ERROR: Could not open output file Woordenlijst1914-full-1.0.tei");
    open(COMPACTFILE, "> Woordenlijst1914-compact-1.0.tei") || die("ERROR: Could not open output file Woordenlijst1914-compact-1.0.tei");

    ###open(LISTFILE, "> list.txt") || die("ERROR: Could not open output file list.txt");
    ###open(CHANGEDFILE, "> changed.txt") || die("ERROR: Could not open output file changed.txt");
    ###open(UNKNOWNSFILE, "> unknown.txt") || die("ERROR: Could not open output file unknown.txt");
    ###open(CASINGFILE, "> casing.txt") || die("ERROR: Could not open output file casing.txt");

    ###open(POSFILE, ">:encoding(iso-8859-1)", "partsofspeech.txt") || die("ERROR: Could not open output file partsofspeech.txt");

    $mode = "skip";

    $lineNumber = 0;
    while (<>) {
        $line = $_;
        $lineNumber++;

        # <!-- START WOORDENLIJST -->
        if ($line =~ /START WOORDENLIJST/) {
            print STDERR "Start processing dictionary\n";
            $mode = "list";
        }

        # <!-- EINDE WOORDENLIJST -->
        if ($line =~ /EINDE WOORDENLIJST/) {
            print STDERR "Done processing dictionary\n";
            $mode = "skip";
        }

        if ($mode eq "list") {
            # [voor]beelden -> -beelden
            # [voor]beelden -> voorbeelden
            #
            # Bijzonder geval:
            #
            # [na]äpen -> -apen
            # [na]äpen -> naäpen
            #
            # ook voor combinaties [aeiou]\][äëïü]

            # Verwijder commentaarregels.
            $line =~ s/<!--(.*?)-->//g;

            $compact = compactLine($line);
            $full = fullLine($line);
            ###collectWords($line);
        } else {
            $compact = $line;
            $full = $line;
        }

        print FULLFILE $full;
        print COMPACTFILE $compact;
    }

    close COMPACTFILE;
    close FULLFILE;

    ###report_words();


    ###close LISTFILE;
    ###close UNKNOWNSFILE;
    ###close CHANGEDFILE;
    ###close CASINGFILE;
}


sub compactLine {
    my $line = shift;
    $line =~ s/\[.*?\]/\&ndash;/g;
    $line =~ s/\^//g;
    return $line;
}


sub fullLine {
    my $line = shift;
    $line =~ s/(\[|\])//g;
    $line =~ s/\^//g;
    return $line;
}


sub special_lowercase {
    my $line = lc shift;
    my $result = "";
    my $remainder = $line;
    while ($remainder =~ /\^([\pL])/) {
        $result .= $`;
        $result .= uc $1;
        $remainder = $';
    }
    $result .= $remainder;
    return $result;
}


%wordHash = ();
%dictHash = ();

sub collectWords {
    my $line = shift;
    $line =~ s/(\[|\])//g;
    $line =~ s/<(.*?)>//g; # Drop SGML/HTML tags
    $line =~ s/\s+/ /g;     # normalize space
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    $line = sgml2utf($line);

    $line = special_lowercase($line);

    tagPartOfSpeech($line);

    my @words = split(/[^\pL\pN\pM-]+/, $line);

    foreach $word (@words) {
        if (!exists $wordHash{$word}) {
            $wordHash{$word} = 1;
        } else {
            $wordHash{$word}++;
        }
    }
}

sub mapGender {
    my $gender = shift;
    my $altgender = shift;
    my $result = $gender eq "o" ? 'n' : ($gender eq "m" ? 'm' : 'f');

    if ($altgender ne "") {
        $result .= $altgender eq "o" ? 'n' : ($altgender eq "m" ? 'm' : 'f');
    }
    return $result;
}


sub testTagPartOfSpeech {
    # Zelfstandige naamwoorden
    tagPartOfSpeech("koffieveiling, v., koffieveilingen.");
    tagPartOfSpeech("aanvalskreet, m., aanvalskreten.");

    tagPartOfSpeech("kop (hoofd), m., koppen. kopje, o., kopjes.");
    tagPartOfSpeech("koffiepot, m., koffiepotten; koffiepotje, o., koffiepotjes.");

    # Werkwoorden.
    tagPartOfSpeech("lachen, lachte, heeft gelachen.");
    tagPartOfSpeech("zouten, zoutte, heeft gezouten.");
    tagPartOfSpeech("praten, praatte, heeft gepraat.");
    tagPartOfSpeech("laden, laadde, heeft geladen.");
    tagPartOfSpeech("remmen, remde, heeft geremd.");
    tagPartOfSpeech("blaffen, blafte, heeft geblaft.");
    tagPartOfSpeech("balken, balkte, heeft gebalkt.");

    tagPartOfSpeech("kleven, kleefde, heeft gekleefd.");
    tagPartOfSpeech("koken, kookte, heeft gekookt.");
    tagPartOfSpeech("razen, raasde, heeft geraasd.");
    tagPartOfSpeech("begrazen, begraasde, heeft begraasd.");
}


sub tagPartOfSpeech {
    my $line = shift;

    # handle apostrophes:
    $line =~ s/\x{2019}/'/g;

    my $disambiguation = "(?: \((?:.*?)\))?";
    my $auxilaryVerb = "(?:is en heeft|heeft en is|heeft|is|hebben)";
    my $genderIndication = "((?<gender>[omv])(\. en (?<altgender>[omv]))?\.)";

    my $doublingConsonant = "[bcdfghklmnprstvw]";
    my $doublingVowel = "[aeou]";

    # === Nouns with gender indication (Zelfstandige naamwoorden met geslachtsaanduiding) ===

    # stam + -en
    # Koffieveiling, V., koffieveilingen.
    if ($line =~ /^(?<base>.*?)$disambiguation, $genderIndication(?<plural>, \k<base>(?<affix>en|\x{203}n|n|s))?(?<diminutive>[.,;] \k<base>(?<letter>[tpk]?)je, o\.(?<pludim>, \k<base>\k<letter>jes)?)?\.?$/) {
        $gender = mapGender($+{gender}, $+{altgender});

        tagWord("$+{base}",             "NN1$gender", 101);
        if ($+{plural} ne "") {
            tagWord("$+{base}$+{affix}",    "NN2$gender", 101);
        }

        if ($+{diminutive} ne "") {
            tagWord("$+{base}$+{letter}je",     "NN1r", 101);

            if ($+{pludim} ne "") {
                tagWord("$+{base}$+{letter}jes",    "NN2r", 101);
            }
        }

        return;
    }

    # verdubbeling medeklinker
    # Kop (hoofd), M., koppen. Kopje, O., [kop]jes.
    # Koffiepot, M., koffiepotten; koffiepotje, O., koffiepotjes.
    if ($line =~ /^(?<base>.*?(?<c>$doublingConsonant))$disambiguation, $genderIndication(?<plural>, \k<base>\k<c>en)?(?<diminutive>[.,;] \k<base>(?<letter>[tpk]?)je, o\.(?<pludim>, \k<base>\k<letter>jes)?)?\.?$/) {
        $gender = mapGender($+{gender});

        tagWord("$+{base}",     "NN1$gender", 102);
        if ($+{plural} ne "") {
            tagWord("$+{base}$+{c}en",  "NN2$gender", 102);
        }

        if ($+{diminutive} ne "") {
            tagWord("$+{base}$+{letter}je",     "NN1r", 102);
            if ($+{pludim} ne "")
            {
                tagWord("$+{base}$+{letter}jes",    "NN2r", 102);
            }
        }

        return;
    }

    # ontdubbeling klinker
    # aanvalskreet, m., aanvalskreten.
    if ($line =~ /^(?<base>(?<pre>.*?(?<v>$doublingVowel))\k<v>(?<c>.))$disambiguation, $genderIndication(?<plural>, \k<pre>\k<c>en)?(?<diminutive>[.,;] \k<base>(?<letter>[tpk]?)je, o\.(?<pludim>, \k<base>\k<letter>jes)?)?\.?$/) {
        $gender = mapGender($+{gender});

        tagWord("$+{base}",     "NN1$gender", 103);
        if ($+{plural} ne "") {
            tagWord("$+{pre}$+{c}en",   "NN2$gender", 103);
        }

        if ($+{diminutive} ne "") {
            tagWord("$+{base}$+{letter}je",     "NN1r", 103);
            if ($+{pludim} ne "") {
                tagWord("$+{base}$+{letter}jes",    "NN2r", 103);
            }
        }

        return;
    }

    # Nouns with male and female forms.
    # Afstammeling, M. en V., [af]stammelingen. V. ook afstammelinge.
    if ($line =~ /^(?<b1>.*?)$disambiguation, $genderIndication, (?<b2>.*?n)\.? v\. ook (?<b3>.*?e)\.?$/) {
        $gender = mapGender($+{gender}, $+{altgender});

        tagWord("$+{b1}",     "NN1$gender", 104);
        tagWord("$+{b2}",     "NN1$gender", 104);
        tagWord("$+{b3}",     "NN1f", 104);

        return;
    }


    # Remaining nouns
    # Koffieuur, O.; koffieuurtje, O.
    # Pan, V., pannen. Pannetje, O., pannetjes.
    if ($line =~ /^(?<b1>.*?)$disambiguation, $genderIndication(?<plural>, (?<b2>.*?(n|s)))?(?<diminutive>[.,;] (?<b3>.*?je), o\.(?<pludim>, (?<b4>.*?jes)))?\.?$/) {
        $gender = mapGender($+{gender});

        tagWord("$+{b1}",       "NN1$gender", 198);
        if ($+{plural} ne "") {
            tagWord("$+{b2}",   "NN2$gender", 198);
        }

        if ($+{diminutive} ne "") {
            tagWord("$+{b3}",       "NN1r", 198);
            if ($+{pludim} ne "") {
                tagWord("$+{b4}",   "NN2r", 198);
            }
        }

        return;
    }

    # Latijnse meervouden.
    # -um -ia/-ea; -man -lui; -us, -i
    if ($line =~ /^(?<b1>.*?(um|man|us))$disambiguation, $genderIndication(?<plural>, (?<b2>.*?(ia|ea|lui|i)))?(?<diminutive>[.,;] (?<b3>.*?je), o\.(?<pludim>, (?<b4>.*?jes)))?\.?$/) {
        $gender = mapGender($+{gender});

        tagWord("$+{b1}",       "NN1$gender", 199);
        if ($+{plural} ne "") {
            tagWord("$+{b2}",   "NN2$gender", 199);
        }

        if ($+{diminutive} ne "") {
            tagWord("$+{b3}",       "NN1r", 199);
            if ($+{pludim} ne "") {
                tagWord("$+{b4}",   "NN2r", 199);
            }
        }

        return;
    }


    # =========================================================================
    # === Verbs (Werkwoorden) ===

    # Typische patronen voor werkwoorden

    # -en, -te, ge- -en
    # Lachen, lachte, heeft gelachen.
    # Zouten, zoutte, heeft gezouten.
    if ($line =~ /(?<base>.*?(?<t>.))en, \k<base>te, $auxilaryVerb ge\k<base>en/) {
        tagWord("$+{base}*",        "VBs", 201);
        if ($+{t} ne "t") {
            tagWord("$+{base}t*",   "VBt", 201);
        }
        tagWord("$+{base}en",       "VBi", 201);
        tagWord("$+{base}te",       "VBp1", 201);
        tagWord("$+{base}ten*",     "VBp2", 201);
        tagWord("ge$+{base}en",     "VBpp", 201);

        return;
    }


    # Praten, praatte, heeft gepraat.
    if ($line =~ /(?<pre>.*?)(?<v>$doublingVowel)ten, (?<base>\k<pre>\k<v>\k<v>t)te, $auxilaryVerb ge\k<base>/) {
        tagWord("$+{base}*",        "VBst", 203);
        tagWord("$+{pre}$+{v}ten",  "VBi", 203);
        tagWord("$+{base}te",       "VBp1", 203);
        tagWord("$+{base}ten*",     "VBp2", 203);
        tagWord("ge$+{base}",       "VBpp", 203);

        return;
    }

    # Laden, laadde, heeft geladen.
    if ($line =~ /(?<pre>.*?)(?<v>$doublingVowel)den, (?<base>\k<pre>\k<v>\k<v>d)de, $auxilaryVerb ge\k<pre>\k<v>den/) {
        tagWord("$+{base}*",        "VBs", 204);
        tagWord("$+{base}t*",       "VBt", 204);
        tagWord("$+{pre}$+{v}den",  "VBi", 204);
        tagWord("$+{base}de",       "VBp1", 204);
        tagWord("$+{base}den*",     "VBp2", 204);
        tagWord("ge$+{pre}$+{v}den", "VBpp", 204);

        return;
    }


    # Remmen, remde, heeft geremd.
    # Blaffen, blafte, heeft geblaft.
    if ($line =~ /(?<base>.*?(?<c>$doublingConsonant))\k<c>en, \k<base>(?<dt>[dt])e, $auxilaryVerb ge\k<base>\k<dt>/) {
        tagWord("$+{base}*",            "VBs", 205);
        tagWord("$+{base}t*",           "VBt", 205);
        tagWord("$+{base}$+{c}en",      "VBi", 205);
        tagWord("$+{base}$+{dt}e",      "VBp1", 205);
        tagWord("$+{base}$+{dt}en*",    "VBp2", 205);
        tagWord("ge$+{base}$+{dt}",     "VBpp", 205);

        return;
    }

    # Balken, balkte, heeft gebalkt.
    if ($line =~ /(?<base>.*?)en, \k<base>te, $auxilaryVerb ge\k<base>t/) {
        tagWord("$+{base}*",        "VBs", 206);
        tagWord("$+{base}t*",       "VBt", 206);
        tagWord("$+{base}$+{c}en",  "VBi", 206);
        tagWord("$+{base}te",       "VBp1", 206);
        tagWord("$+{base}ten*",     "VBp2", 206);
        tagWord("ge$+{base}t",      "VBpp", 206);

        return;
    }


    # Kleven, kleefde, heeft gekleefd.
    if ($line =~ /(?<pre>.*?)(?<v>$doublingVowel)ven, (?<base>\k<pre>\k<v>\k<v>f)de, $auxilaryVerb ge\k<base>d/) {
        tagWord("$+{base}*",        "VBs", 207);
        tagWord("$+{base}t*",       "VBt", 207);
        tagWord("$+{pre}$+{v}ven",  "VBi", 207);
        tagWord("$+{base}de",       "VBp1", 207);
        tagWord("$+{base}den*",     "VBp2", 207);
        tagWord("ge$+{base}d",      "VBpp", 207);

        return;
    }

    # Koken, kookte, heeft gekookt.
    if ($line =~ /(?<pre>.*?)(?<v>$doublingVowel)(?<c>.)en, (?<base>\k<pre>\k<v>\k<v>\k<c>)te, $auxilaryVerb ge\k<base>t/) {
        tagWord("$+{base}*",            "VBs", 208);
        tagWord("$+{base}t*",           "VBt", 208);
        tagWord("$+{pre}$+{v}$+{c}en",  "VBi", 208);
        tagWord("$+{base}te",           "VBp1", 208);
        tagWord("$+{base}ten*",         "VBp2", 208);
        tagWord("ge$+{base}t",          "VBpp", 208);

        return;
    }

    # razen, raasde, heeft geraasd
    if ($line =~ /(?<pre>.*?)(?<v>$doublingVowel)zen, (?<base>\k<pre>\k<v>\k<v>s)de, $auxilaryVerb ge\k<base>d/) {
        tagWord("$+{base}*",        "VBs", 209);
        tagWord("$+{base}t*",       "VBt", 209);
        tagWord("$+{pre}$+{v}zen",  "VBi", 209);
        tagWord("$+{base}de",       "VBp1", 209);
        tagWord("$+{base}den*",     "VBp2", 209);
        tagWord("ge$+{base}t",      "VBpp", 209);

        return;
    }

    # Remaining verbs
    # Loopen, liep, heeft en is geloopen.
    # Begrazen, begraasde, heeft begraasd.
    # Koekhakken, hakte koek, heeft koekgehakt.
    if ($line =~ /^(?<b1>[^,]*?n)$disambiguation, (?<b2>[^,]*?), $auxilaryVerb (?<b3>(be|ge|ver)?.*?)\.?$/) {
        tagWord("$+{b1}",   "VBi", 299);
        tagWord("$+{b2}",   "VBp1", 299);
        tagWord("$+{b3}",   "VBpp", 299);

        return;
    }

    # Remaining verbs (4 forms)
    # Rijden, reed, reden, heeft en is gereden.
    if ($line =~ /^(?<b1>[^,]*?n)$disambiguation, (?<b2>[^,]*?), (?<b4>[^,]*?), $auxilaryVerb (?<b3>(be|ge|ver)?.*?)\.?$/) {
        tagWord("$+{b1}",   "VBi", 299);
        tagWord("$+{b2}",   "VBp1", 299);
        tagWord("$+{b4}",   "VBp2", 299);
        tagWord("$+{b3}",   "VBpp", 299);

        return;
    }


    # =========================================================================
    # === Adjectives with grades (Bijvoegelijke naamwoorden met trappen van vergelijking) ===

    # algemene regel
    # mooi, mooier, mooist                  + mooie, mooiere, mooiste, mooien, mooieren, mooisten
    if ($line =~ /(?<base>.*?), \k<base>er, \k<base>st/) {
        tagWord("$+{base}",         "AJ",  301);
        tagWord("$+{base}er",       "AJc", 301);
        tagWord("$+{base}st",       "AJs", 301);

        tagWord("$+{base}e*",       "AJ",  301);
        tagWord("$+{base}ere*",     "AJc", 301);
        tagWord("$+{base}ste*",     "AJs", 301);

        tagWord("$+{base}en*",      "AJ",  301);
        tagWord("$+{base}eren*",    "AJc", 301);
        tagWord("$+{base}sten*",    "AJs", 301);

        return;
    }

    # verdubbeling van de medeklinker
    # knap, knapper, knapst                                             + knappe, knappere, knapste
    if ($line =~ /(?<base>.*?(?<c>$doublingConsonant)), \k<base>\k<c>er, \k<base>st/) {
        tagWord("$+{base}",             "AJ",  302);
        tagWord("$+{base}$+{c}er",      "AJc", 302);
        tagWord("$+{base}st",           "AJs", 302);

        tagWord("$+{base}$+{c}e*",      "AJ",  302);
        tagWord("$+{base}$+{c}ere*",    "AJc", 302);
        tagWord("$+{base}ste*",         "AJs", 302);

        tagWord("$+{base}$+{c}en*",     "AJ",  302);
        tagWord("$+{base}$+{c}eren*",   "AJc", 302);
        tagWord("$+{base}sten*",        "AJs", 302);

        return;
    }


    # assimilatie s bij sch (DVTW) en s
    # versch, verscher, verscht
    # Paars, paarser, paarst.
    if ($line =~ /(?<base>.*?s(ch)?), \k<base>er, \k<base>t/) {
        tagWord("$+{base}",     "AJ", 303);
        tagWord("$+{base}er",   "AJc", 303);
        tagWord("$+{base}t",    "AJs", 303);

        tagWord("$+{base}e*",   "AJ", 303);
        tagWord("$+{base}ere*", "AJc", 303);
        tagWord("$+{base}te*",  "AJs", 303);

        tagWord("$+{base}en*",  "AJ", 303);
        tagWord("$+{base}eren*",    "AJc", 303);
        tagWord("$+{base}ten*", "AJs", 303);

        return;
    }

    # Frisch, frisscher, frischt.
    if ($line =~ /(?<base>(?<pre>.*?)sch), \k<pre>sscher, \k<pre>scht/) {
        tagWord("$+{base}",     "AJ", 309);
        tagWord("$+{pre}sscher",   "AJc", 309);
        tagWord("$+{base}t",    "AJs", 309);

        tagWord("$+{pre}ssche*",   "AJ", 309);
        tagWord("$+{pre}sschere*", "AJc", 309);
        tagWord("$+{base}te*",  "AJs", 309);

        tagWord("$+{pre}sschen*",  "AJ", 309);
        tagWord("$+{pre}sscheren*",    "AJc", 309);
        tagWord("$+{base}ten*", "AJs", 309);

        return;
    }



    # s -> z
    # vies, viezer, viest
    if ($line =~ /(?<base>(?<pre>.*?)s), \k<pre>zer, \k<base>t/) {
        tagWord("$+{base}",     "AJ", 304);
        tagWord("$+{pre}zer",   "AJc", 304);
        tagWord("$+{base}t",    "AJs", 304);

        tagWord("$+{pre}ze*",   "AJ", 304);
        tagWord("$+{pre}zere*", "AJc", 304);
        tagWord("$+{base}te*",  "AJs", 304);

        tagWord("$+{pre}zen*",  "AJ", 304);
        tagWord("$+{pre}zeren*",    "AJc", 304);
        tagWord("$+{base}ten*", "AJs", 304);

        return;
    }

    # f -> v
    # doof, doover, doofst (alleen DVTW)
    # lief, liever, liefst
    if ($line =~ /(?<base>(?<pre>.*?)f), \k<pre>ver, \k<base>st/) {
        tagWord("$+{base}",     "AJ", 305);
        tagWord("$+{pre}ver",   "AJc", 305);
        tagWord("$+{base}st",   "AJs", 305);

        tagWord("$+{pre}ve*",   "AJ", 305);
        tagWord("$+{pre}vere*", "AJc", 305);
        tagWord("$+{base}ste*", "AJs", 305);

        tagWord("$+{pre}ven*",  "AJ", 305);
        tagWord("$+{pre}veren*",    "AJc", 305);
        tagWord("$+{base}sten*",    "AJs", 305);

        return;
    }

    # ontdubbeling van de klinker en f -> v
    # doof, dover, doofst (modern)
    # gaaf, gaver, gaafst
    if ($line =~ /(?<base>(?<pre>.*?(?<v>$doublingVowel))\k<v>f), \k<pre>ver, \k<base>st/) {
        tagWord("$+{base}",         "AJ",  306);
        tagWord("$+{pre}ver",       "AJc", 306);
        tagWord("$+{base}st",       "AJs", 306);

        tagWord("$+{pre}ve*",       "AJ",  306);
        tagWord("$+{pre}vere*",     "AJc", 306);
        tagWord("$+{base}ste*",     "AJs", 306);

        tagWord("$+{pre}ven*",      "AJ",  306);
        tagWord("$+{pre}veren*",    "AJc", 306);
        tagWord("$+{base}sten*",    "AJs", 306);

        return;
    }

    # ontdubbeling van de klinker
    # vaak, vaker, vaakst
    if ($line =~ /(?<base>(?<pre>.*?(?<v>$doublingVowel))\k<v>(?<c>.)), \k<pre>\k<c>ver, \k<base>st/) {
        tagWord("$+{base}",         "AJ",  307);
        tagWord("$+{pre}$+{c}er",       "AJc", 307);
        tagWord("$+{base}st",       "AJs", 307);

        tagWord("$+{pre}$+{c}e*",       "AJ",  307);
        tagWord("$+{pre}$+{c}ere*",     "AJc", 307);
        tagWord("$+{base}ste*",     "AJs", 307);

        tagWord("$+{pre}$+{c}en*",      "AJ",  307);
        tagWord("$+{pre}$+{c}eren*",    "AJc", 307);
        tagWord("$+{base}sten*",    "AJs", 307);

        return;
    }

    # ontdubbeling van de klinker en s -> z
    # dwaas, dwazer, dwaast
    if ($line =~ /(?<base>(?<pre>.*?(?<v>$doublingVowel))\k<v>s), \k<pre>zer, \k<base>t/) {
        tagWord("$+{base}",         "AJ",  308);
        tagWord("$+{pre}zer",       "AJc", 308);
        tagWord("$+{base}t",        "AJs", 308);

        tagWord("$+{pre}ze*",       "AJ",  308);
        tagWord("$+{pre}zere*",     "AJc", 308);
        tagWord("$+{base}te*",      "AJs", 308);

        tagWord("$+{pre}zen*",      "AJ",  308);
        tagWord("$+{pre}zeren*",    "AJc", 308);
        tagWord("$+{base}ten*",     "AJs", 308);

        return;
    }

    # Adjectives without comparatives
    if ($line =~ /^(?<base>.*?)$disambiguation, (\k<base>e)\.?$/) {
        tagWord("$+{base}",     "AJ",  330);
        tagWord("$+{base}e",    "AJ",  330);
        return;
    }

    if ($line =~ /^(?<base>(?<pre>.*?)(?<v>$doublingVowel)\k<v>(?<c>.))$disambiguation, \k<pre>\k<v>\k<c>e\.?$/) {
        tagWord("$+{base}",     "AJ",  331);
        tagWord("$+{pre}$+{v}$+{c}e",   "AJ",  331);
        return;
    }

    if ($line =~ /^(?<base>(?<pre>.*?)(?<v>$doublingVowel)\k<v>s)$disambiguation, \k<pre>\k<v>ze\.?$/) {
        tagWord("$+{base}",     "AJ",  332);
        tagWord("$+{pre}$+{v}ze",   "AJ",  332);
        return;
    }

    if ($line =~ /^(?<base>(?<pre>.*?)s)$disambiguation, \k<pre>ze\.?$/) {
        tagWord("$+{base}",     "AJ",  333);
        tagWord("$+{pre}ze",   "AJ",  333);
        return;
    }

    if ($line =~ /^(?<base>(?<pre>.*?)f)$disambiguation, \k<pre>ve\.?$/) {
        tagWord("$+{base}",     "AJ",  333);
        tagWord("$+{pre}ve",   "AJ",  333);
        return;
    }

    if ($line =~ /^(?<base>(?<pre>.*?)(?<v>$doublingVowel)\k<v>f)$disambiguation, \k<pre>\k<v>ve\.?$/) {
        tagWord("$+{base}",     "AJ",  334);
        tagWord("$+{pre}$+{v}ve",   "AJ",  334);
        return;
    }

    if ($line =~ /^(?<base>(?<pre>.*?)(?<c>$doublingConsonant))$disambiguation, \k<base>\k<c>e\.?$/) {
        tagWord("$+{base}",     "AJ",  335);
        tagWord("$+{base}$+{c}e",   "AJ",  335);
        return;
    }


    # Remaining adjectives:
    if ($line =~ /^(?<b1>.*?)$disambiguation, (?<b2>.*?er), (?<b3>.*?st)\.?$/) {
        tagWord("$+{b1}",   "AJ",  399);
        tagWord("$+{b2}",   "AJc", 399);
        tagWord("$+{b3}",   "AJs", 399);
        return;
    }

    # Adjectives with meest
    if ($line =~ /^(?<b1>.*?)$disambiguation, (?<b2>.*?er), meest \k<b1>\.?$/) {
        tagWord("$+{b1}",   "AJ",  399);
        tagWord("$+{b2}",   "AJc", 399);
        tagWord("meest $+{b1}", "AJs",  399);
        return;
    }

    # =========================================================================
    # === Other words (Andere woorden) ===

    # (tusschenw.)
    if ($line =~ /^(?<word>.*?) \(tusschenw\.\)\.?$/) {
        tagWord("$+{word}", "INJ", 600);
        return;
    }

    # (bijw.)
    if ($line =~ /^(?<word>.*?) \(bijw\.?\)\.?$/) {
        tagWord("$+{word}", "AV", 602);
        return;
    }

    # (bnw.)
    if ($line =~ /^(?<word>.*?) \(bnw\.?\)\.?$/)
    {
        tagWord("$+{word}", "AJ", 603);
        return;
    }

    # (voorz.)
    if ($line =~ /^(?<word>.*?) \(voorz\.\)\.?$/) {
        tagWord("$+{word}", "PR", 604);
        return;
    }


    # =========================================================================

    # Cross references
    if ($line =~ /^(?<b1>.*?). zie (?<b2>.*?)\.?$/) {
        tagWord("$+{b1}\t$+{b2}", "XREF", 800);
        return;
    }

    # Unhandled lines (Unclassified)
    if ($line ne "") {
        tagWord("$line", "UNC", 999);
        return;
    }
}


sub tagWord {
    my $word = shift;
    my $tag = shift;
    my $rule = shift;

    $word =~ s/\.$//;

    if ($word =~ /^(.*?) en (.*?)$/) {
        $word = $2;
        my $alternateWord = $1;
        print POSFILE "$lineNumber\t$tag\t$rule*\t$alternateWord\n";
    }

    print POSFILE "$lineNumber\t$tag\t$rule\t$word\n";
}


sub load_dictionary {
    open(DICTFILE, "C:\\bin\\dic\\nl.dic") || die "Could not open C:\\bin\\dic\\nl.dic";

    %dictHash = ();
    while (<DICTFILE>) {
        my $word =  $_;
        $word =~ s/\n//g;
        my $normword = normalize_dutch_word($word);

        if (exists $dictHash{$normword}) {
            $dictHash{$normword} .= "; $word"
        } else {
            $dictHash{$normword} = "$word";
        }
    }
    close(DICTFILE);
}


sub load_dictionary_100g {
    open(DICTFILE, "basiswoorden290507-utf8.txt") || die "Could not open basiswoorden290507-utf8.txt";

    %dictHash = ();
    while (<DICTFILE>) {
        my $word =  $_;
        $word =~ s/\n//g;
        my $normword = normalize_dutch_word($word);

        if (exists $dictHash{$normword}) {
            $dictHash{$normword} .= "; $word"
        } else {
            $dictHash{$normword} = "$word";
        }
    }
    close(DICTFILE);
}


sub normalize_dutch_word {
    my $word = shift;

    # Spelling De Vries-Te Winkel
    $word =~ s/\Bsch/s/g;                               # mensch -> mens
    $word =~ s/oo([bcdfghklmnprst])([aeiou])/o\1\2/g;   # rooken -> roken
    $word =~ s/ee([bcdfghklmnprst])([aeiou])/e\1\2/g;   # leenen -> lenen
    $word =~ s/ph/f/g;                                  # photographie -> fotografie
    $word =~ s/oeie/oei/g;                              # moeielijk -> moeilijk
    $word =~ s/qu/kw/g;                                 # questie -> kwestie
    $word =~ s/c/k/g;                                   # vacantie -> vakantie
    $word =~ s/ae/e/g;                                  # quaestie -> kwestie
    $word =~ s/lli/lj/g;                                # millioen -> miljoen
    $word =~ s/rh/r/g;                                  # rhetorica -> retorica

    return lc $word;
}



sub report_words {
    load_dictionary_100g();

    my @wordList = keys %wordHash;
    @wordList = sort {lc($a) cmp lc($b)} @wordList;

    foreach $word (@wordList) {
        print LISTFILE "$word\n";
        my $normword = normalize_dutch_word($word);
        if (exists $dictHash{$normword}) {
            my $modernWords = $dictHash{$normword};
            if ($modernWords ne $word) {
                print CHANGEDFILE "$word : $modernWords\n";
            }

            if ($modernWords ne $word && lc($modernWords) eq lc($word)) {
                print CASINGFILE "$word : $modernWords\n";
            }
        } else {
            print UNKNOWNSFILE "$word\n";
        }
    }
}
