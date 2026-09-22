Part 7 of the project was handled separately from the software optimization work. I was responsible for selecting the accelerated component, defining the hardware/software boundary and making the design and implememntation choices. Codex was used as an interactive implementation and verification tool during this process.

תשתמש בריפו החדש.

אני צריך לעשות את החלק של hardware acceleration אבל לפני שאני מתחיל לכתוב משהו אני רוצה להבין מה בכלל שווה להעביר לחומרה.

תסתכל על Pyflate בעיקר.

אני רואה הרבה דברים קטנים שם, לא משהו אחד ענק.

---

ה-Huffman נראה לי מעניין אבל אני לא בטוח אם זה באמת מה שתוקע.

יש לי profiling ישן אבל אני לא כל כך סומך עליו.

איפה הפונקציה של ה-Huffman עצמה?

תראה לי מה היא עושה פשוט.

---

בלי לדבר עדיין על חומרה.

למה היא עושה את זה בלולאה?

אז כל symbol זה כמה בדיקות כאלה?

---

הרצתי profile מחדש.

יש לי:

total 4.101 sec

ובתוך `find_next_symbol` 1.667 sec.

---

כמה זה?

---

זה פחות ממה שהיה לי פעם.

היה לי מספר של בערך 67%.

---

כן, אל תשתמש ב-67 הזה.

אני לא יודע מספיק טוב מאיפה הוא הגיע.

הרצתי שוב ועכשיו יצא 42.9%.

יש הבדל אבל לא מטורף.

---

אני חושב שאשתמש ב-40.6 כי לפחות זה יותר שמרני.

אבל עדיין צריך לעשות את זה ב-QEMU של הקורס בסוף.

---

רגע משהו אחר.

למה Huffman פה נקרא canonical?

---

אני מכיר את הרעיון של Huffman tree אבל פה אני לא רואה tree בכלל.

אז בעצם לא צריך tree?

---

זה דווקא טוב בשביל חומרה.

תראה לי מספרים קטנים עם דוגמה.

נגיד יש codes באורך 2 ו-3.

---

אוקיי הבנתי.

`first_symbol_index` זה פשוט offset?

---

סבבה.

אם אנחנו כבר עושים את זה בחומרה, אולי אפשר לעשות lookup table ענק של 20 bits ופשוט לקבל symbol ישר?

---

כמה זה entries?

---

טוב עזוב.

לא צריך.

מה החלק הכי איטי בתוך `find_next_symbol`?

---

יש שם משהו אחד בולט או שזה פשוט Python עושה הרבה פעולות קטנות?

אז לא צריך איזה multiplier או משהו.

---

אוקיי.

תסתכל על איך הביטים מגיעים לפונקציה.

אני לא רוצה מצב שאני מאיץ lookup אבל כל symbol עדיין Python מעביר 20 bits לחומרה.

זה יהיה מטופש.

---

מה זה מחזיק בפנים?

אז עדיף שהחומרה תחזיק buffer משלה ותאכל bytes.

---

אוקיי.

אבל אז איפה בדיוק עושים handoff?

---

ה-Python הרי צריך לקרוא את כל ה-header קודם בשביל לבנות את ה-Huffman tables.

אז אחרי שהטבלאות מוכנות?

תבדוק בקוד אם בדיוק שם אנחנו תמיד על byte boundary.

---

אה.

תראה לי למה.

אז אם אני פשוט נותן לחומרה את שאר הקובץ מה-file pointer אני מאבד bits.

---

טוב שתפסנו את זה עכשיו.

כמה state צריך להעביר?

רק כמה bits + count?

---

אוקיי.

אל תבנה interface עדיין, רק לזכור את זה.

חזרתי לקוד של BZip2.

מה זה `selectors` שם?

---

רגע.

אני חשבתי שיש table אחת לכל block.

אז כל מה שחשבנו על table אחת לא מספיק.

כמה יש מקסימום?

---

שש בכל block?

---

ואז selector אומר כל פעם מי מהם פעיל?

---

כל symbol?

---

אה.

זה משהו של BZip2 עצמו או רק Pyflate עושה את זה ככה?

---

אוקיי.

אפשר פשוט לשמור table אחת בחומרה וכל 50 symbols לטעון את הבאה?

---

כמה זמן לטעון טבלה כזאת?

---

כן.

אז אולי פשוט שש banks.

כמה זיכרון זה בערך?

---

לא נשמע נורא.

נעשה שש.

אבל לא צריך שש יחידות decode נכון?

---

כן.

מה selector עצמו צריך לדעת החומרה?

---

אולי אפשר פשוט לשלוח לה selector number.

אז כרגע נעשה רק bank select.

אם אחר כך צריך יותר מזה נראה.

אני רוצה לחשוב על lookup עצמו.

---

אם אני בודק כל length במקביל זה cycle אחד.

כמה lengths יש?

---

20 comparators זה באמת כזה נורא?

---

ואם אחד כל cycle?

---

אני נוטה לפשוט.

זה קורס, לא מוצר.

מצד שני אם כל code יהיה 20 bits זה איטי.

---

כן.

בוא נעשה iterative.

אם אחר כך נראה שזה דפוק נשנה.

מה ה-state של FSM כזה?

---

צריך state נפרד לכל length?

---

יותר הגיוני.

עכשיו איך היית מחלק את הקבצים?

---

כן.

אל תעשה לי 8 modules.

תתחיל מה-bit buffer.

64 bits נשמע לי מספיק.

---

למה 64 ולא 32?

---

אנחנו צריכים מקסימום 20 bits קדימה, נכון?

אז 32 גם מספיק ברוב הזמן.

---

טוב, לא אכפת לי מספיק בשביל להתווכח על זה.

64.

תראה לי איך ה-bits יושבים שם.

MSB בצד העליון?

---

וזה תואם Pyflate?

---

טוב.

מה קורה כשמגיע byte חדש?

---

ומה קורה אם באותו cycle decoder אומר consume 7?

---

יש פה שתי assignments לאותו register?

אז תעשה next value אחד.

אני מעדיף לא להסתמך על order של nonblocking.

אפשר test קטן רק ל-buffer?

---

תעשה.

נגיד שני bytes ואז consume 3 ואז consume עוד 5.

ועוד אחד עם seed bits.

כרגע seed זה סתם כמה bits שאנחנו בוחרים, נכון?

---

סבבה.

תריץ lint.

מה זה warning של width פה?

---

זה יכול באמת לעשות bug?

אז לתקן.

יש עוד warning.

לא משנה.

---

עכשיו decoder.

אני רוצה לפני שאתה כותב שתראה לי שוב את הנוסחה של ה-prefix.

למה עושים shift מ-20?

---

כן.

אם יש רק 12 bits זמינים ו-current length הוא 15 אז אסור לנסות בכלל.

אז decoder צריך לדעת כמה bits buffered.

---

אוקיי.

תממש.

אני רואה שיש array לפי length.

SystemVerilog/Yosys אוהב את זה?

---

בוא לא נניח.

אחר כך נריץ synthesis.

מה קורה ל-length שאין בו אף code?

---

יש לנו flag או פשוט first > last?

תעשה מה שהכי פשוט.

`symbol_memory` צריך להיות לכל bank גם?

---

וזה 9 bit?

---

למה 9 ולא 8?

---

אה נכון.

אני חושב שב-index גם צריך 9.

תוסיף bank select.

הקונפיגורציה של הטבלאות נעשית דרך ports?

---

לא רוצה readmemh כי בפועל זה צריך להגיע מה-software.

למה יש `cfg_table_select` וגם `decode_table_select`?

---

כן, תשאיר ככה.

תעשה top.

אפשר בלי ready/valid ולעשות start/done?

---

מה יותר פשוט לטסט?

---

טוב, ready/valid.

`busy` עדיין צריך אם יש `decode_ready`?

---

תשאיר.

עכשיו testbench.

משהו ממש קטן קודם.

תראה לי את הטבלה לפני שאתה מריץ.

---

אני מנסה לבדוק ידנית.

למה symbol 3 יוצא מ-`110`?

---

אוקיי.

תריץ.

מה expected ומה actual?

---

תדפיס את ה-buffer לפני decode.

זה נראה לי הפוך.

אנחנו מכניסים את ה-byte בכיוון הלא נכון בטסט אולי.

---

כן.

אל תשנה RTL.

לתקן את הטסט.

עובר עכשיו?

תוסיף code שחוצה byte boundary.

---

לא, לא להתחיל אותו בתחילת byte.

תשים לפניו כמה bits כדי שבאמת יחצה.

עכשיו כן.

מה קורה אם יש רק חצי code ואז אין עוד bytes?

---

למה error?

---

פשוט אין input.

תוסיף `need_more_bits` או משהו כזה.

ואז כשה-byte הבא מגיע הוא ממשיך מאותו state?

תבדוק את זה.

---

סבבה.

תעשה test לשני banks.

אותם bits, אבל כל bank מחזיר symbol אחר.

עובר?

---

bank 7?

---

אני יודע, תבדוק מה קורה.

טוב.

תריץ Icarus.

Verilator.

---

זה warning של RTL או test?

---

עזוב.

חשבתי על משהו.

אולי בכלל עדיף להאיץ גם MTF יחד עם Huffman כי אחרת אנחנו מחזירים symbols ל-Python כל הזמן.

כמה מסובך MTF?

---

לא.

לא נכנס לזה.

אבל אז communication overhead יכול להיות בעיה.

---

ברור.

לא נממש DMA עכשיו.

חזרה ל-selector.

אם הוא משתנה כל 50 symbols, אולי top יכול לספור בעצמו 50 ולהתקדם ב-selector list.

---

זה דווקא לא כזה קשה.

כן.

נשאיר control חיצוני כרגע.

אבל בדוח צריך להיות ברור שהחומרה יודעת לבחור table, לא שהיא מפענחת בעצמה את ה-selectors.

---

אני רוצה real test.

ה-directed tests נחמדים אבל אני לא יודע אם יש משהו ב-Pyflate שאנחנו מפספסים.

מה לשמור?

---

צריך לשמור את כל bytes אחרי handoff?

תעשה משהו פשוט.

לא JSON ענק אם לא חייבים.

איך אתה מוציא code length מה-Python?

אז תשמור גם symbol וגם length.

---

אם רק symbol מתאים יכול להיות שאנחנו בכל זאת אוכלים wrong number of bits ואז ניפול אחר כך.

תוסיף instrumentation בלי לשנות decode behavior.

תריץ על input של benchmark.

כמה symbols?

---

זה בערך מתאים למספר calls שראינו, נכון?

---

טוב.

מה היה buffer state בזמן handoff?

---

מה הם?

---

מעניין.

תבדוק את זה שוב.

כאילו ממש לפני ה-Huffman loop.

וה-file pointer כבר אחרי ה-byte שלהם?

אז seed באמת חובה פה.

---

איך `1110` נכנס ל-seed_data?

אני רוצה לוודא שלא שוב נהפוך bits.

תוסיף test בדיוק עם 4 bits האלה.

לא רק random seed.

---

עובר?

---

עכשיו testbench של כל ה-trace.

זה כנראה יהיה איטי בסימולציה.

---

טוב.

תריץ.

יש mismatch?

---

כמה באמת השווה לפני שסיים?

---

גם length?

---

טוב מאוד.

כל banks הופיעו?

---

אני שואל כי אם table 5 לא היה בשימוש אז real test לא באמת בדק אותו.

סבבה.

אם היה mismatch באמצע, כרגע הטסט היה ממשיך עד הסוף?

---

תשנה שידפיס first mismatch עם buffer state.

לא צריך אלפי errors.

אין mismatch עכשיו אבל זה עדיין יותר נוח אם נשבור משהו אחר כך.

תעשה summary בסוף עם count.

---

`ALL TESTS PASSED` זה קצת דרמטי אבל בסדר.

אני רוצה לבדוק משהו אחר.

כמה פעמים כל code length הופיע?

---

אפשר מזה להבין כמה cycles iterative decoder עושה?

---

תחשב.

2.361 checks average?

אז זה ממש בסדר.

חשבתי שיהיה הרבה יותר.

---

אבל wait, אם code length נגיד 10 זה לא אומר 10 checks, כי מתחילים ב-min length.

סבבה.

תחשב total cycles.

---

כן.

תכלול request cycle, כל length check, ו-result cycle.

זה לכל ה-148271?

תחשב average per symbol.

---

לא צריך לדוח כנראה, סתם רציתי לראות.

100 MHz זה 10ns נכון?

אז 646642 cycles זה בערך 6.46ms.

---

אוקיי.

אבל זה רק decoder cycles.

לא loading tables.

ולא DMA.

---

ולא driver.

טוב.

100 MHz זה סתם מספר שהמצאנו?

---

אין timing בכלל כרגע.

אז לא לכתוב שזה עובד ב-100MHz.

עכשיו בא לי לבדוק אם parallel decoder באמת היה שווה משהו.

אם average checks 2.361 אז אולי בכלל לא.

---

כן.

אז הבחירה הזאת יצאה טובה במקרה של הקלט הזה.

אבל לא להגיד שזה תמיד יותר טוב.

מה אם היינו עושים two lengths per cycle?

---

לא.

אין צורך.

יש עוד optimization פשוט?

---

לא משנה.

בוא נחשב Amdahl.

עם 40.6%.

תן לי 2,4,8 וגם אינסופי.

---

8x נותן בערך 1.55?

---

ואינסופי 1.68.

אז אין סיכוי ל-2x overall רק מהחלק הזה.

זה דווקא טוב לדעת.

אבל ה-8x מאיפה יבוא?

---

כן.

צריך לכתוב effective speedup כולל communication overhead.

אם ניקח רק 6.47ms ונשווה ל-1.667s זה נראה פי מאות.

---

בדיוק.

אז לא לעשות את זה.

צריך synthesis עכשיו.

תריץ generic.

---

עבר?

---

memories?

---

למה 7?

---

אוקיי.

חשבתי שיהיה בדיוק 6 בגלל banks.

כמה bits?

---

זה לא כולל bit buffer נכון?

---

טוב.

תחשב כמה היה עם table אחת.

בערך 17K bits חיסכון?

---

לא מעט.

אולי עדיף table אחת בכל זאת?

---

כן, לא.

נשאיר שש.

אפשר לשמור רק 2 ולהחליף לפי הצורך?

אבל אז צריך לדעת איזה selector מגיע בהמשך ולהביא table אם חסר.

---

עזוב.

זה סתם נהיה פרויקט אחר.

Yosys נותן area?

אבל יש cell count.

---

אז אני לא צריך את זה.

power בטח בכלל לא.

---

כן.

אפשר לפחות להגיד iterative פחות switching מה-parallel?

---

סבבה.

מה זה clock gating פה?

---

זה משהו שהיית מוסיף?

אז לא לממש.

אולי משפט future work.

אני חוזר רגע ל-interface.

---

אם DMA קורא 64 bytes קדימה וה-Huffman נגמר אחרי חצי מזה, ה-file pointer של software כבר לא נכון.

אז צריך consumed bits.

כבר יש `bits_consumed` לכל symbol אבל ברמת block אפשר לצבור.

---

טוב.

איך software flow נראה אז?

לא צריך API אמיתי.

רק משהו להסבר.

---

תכתוב לי שלוש פונקציות pseudo כאלה.

כן זה מספיק.

יש משהו מוזר עם selector list והתרשים.

אם אני מצייר CPU שולח selectors ל-table banks זה נשמע כאילו ה-banks עצמם יודעים selector stream.

---

אוקיי.

אני רוצה לראות שוב איפה בקוד selector מתחלף אחרי 50.

---

כן.

שכחתי בדיוק איך זה מתקדם.

יש סיכוי שקבוצה אחרונה היא פחות מ-50?

אז אם היינו עושים counter בחומרה היינו צריכים לטפל בזה.

---

עוד סיבה לא לעשות כרגע.

מה עוד חסר בטסטים?

---

reconfigure bank שכבר היה loaded בדקנו?

---

תוסיף.

עבר?

---

reset באמצע stream?

---

יש לזה test?

תוסיף אחד קצר.

לא יודע אם צריך לדוח אבל עדיף.

---

סבבה.

משהו לא ברור לי ב-`seed_count`.

למה הוא 7 bits?

---

6 bits מגיע רק עד 63.

טוב.

`buffered_bits` גם 7.

מה קורה אם seed_count 64 ואז מגיע byte?

---

יש test לזה?

תוסיף אולי.

עבר.

אני רוצה להריץ שוב את real trace אחרי כל השינויים האלה.

---

148271 עדיין?

---

טוב.

עכשיו אני מתחיל לכתוב את החלק בדוח.

מה היית שם קודם, profiling או architecture?

---

כן.

במשפט הראשון אני לא רוצה להגיד "the bottleneck is Huffman" חזק מדי.

כי בפועל 40%.

---

כן.

גם "148000 times in one decompression" זה מה-trace שלנו.

לא חוק של Pyflate.

---

טוב.

אני כותב עכשיו "During the real-input test we found BZip2 can use six groups".

זה לא מדויק בעצם, נכון?

אז אני צריך לשנות את המשפט.

---

איך היית כותב את זה בלי להישמע חופר?

---

סבבה.

בתרשים אני שם DMA/FIFO למרות שלא מימשנו אותם.

זה בסדר?

---

אוקיי.

אני עדיין לא בטוח אם לכתוב 100MHz בטבלה.

---

כן.

יש טעם להריץ STA בלי FPGA?

---

טוב.

מה ההבדל בין generic synthesis ל-place and route בהקשר הזה?

---

אוקיי.

אז Yosys נותן לי יותר "זה synthesizable ואיזה logic/memories יש", לא "כמה מהר זה באמת".

אני רוצה לוודא שה-performance section לא עושה double counting.

ה-646642 cycles כולל output handshake.

---

אבל לא כולל input DMA.

ולא config.

אם output consumer לא ready, זה יוסיף cycles מעבר למודל.

אז המודל מניח response accepted בלי stalls.

---

צריך אולי להגיד את זה.

עוד שאלה.

אם code לא חוקי אבל עדיין יש מספיק bits, איך decoder יודע שזה invalid ולא פשוט מחכה?

---

כן.

זה distinction טוב.

תבדוק שה-test של invalid code באמת מגיע למצב הזה ולא פשוט underflow.

---

טוב.

מה הסיפור של seven memories עוד פעם?

---

אוקיי.

אני כנראה לא אכתוב seven בפירוט, רק ש-Yosys inferred memories וה-total bits.

יש סיבה לשמור את bounds ב-registers ולא memory?

---

לא משנה.

אם הייתי עושה FPGA אמיתי, אולי BRAM היה wasted כי הטבלאות קטנות.

---

טוב, לא רלוונטי.

תן לי עוד פעם את Amdahl table.

---

סבבה.

מוזר שפי 4 בחלק נותן רק 1.44 overall.

---

כן.

אז אם היינו רוצים מעבר ל-1.68 צריך להאיץ גם שלב אחר.

לא לפרויקט הזה.

תעבור רגע על כל הקבצים תחת `pyflate/hardware`.

---

יש משהו ששכחנו להסיר? debug prints, TODOs, דברים כאלה.

יש TODO על selector.

תשנה comment שזה intentionally external control, לא TODO כאילו חסר implementation.

תבדוק שה-comments לא נשמעים כאילו DMA קיים.

---

טוב.

עכשיו full test פעם אחרונה.

Icarus?

---

Verilator?

---

trace?

---

Yosys?

---

טוב.

יש משהו שאתה חושב שהדוח טוען יותר מדי ביחס למה שבדקנו?

---

את frequency כבר החלשתי.

area אין מספר פיזי.

וה-1.55 זה estimated, לא measured.

אני רוצה שהמסקנה תגיד שה-RTL reproduces Pyflate Huffman behavior על supplied input.

---

לא "the accelerator is fully correct".

כן.

ה-profiling עדיין מקומי.

אם לא יהיה לי זמן להריץ QEMU לפני ההגשה מה לעשות?

---

כן.

לא להסתיר.

---

סבבה.

אני חושב שסיימתי את החלק הזה.
