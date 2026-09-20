# AI Tool Usage

Tool used: ChatGPT Codex.

The work was developed through a Hebrew conversation rather than one long
standalone prompt. Representative user prompts/instructions, quoted verbatim,
were:

1. `חלק 7 לדעתך סביר בגודלו?`
2. `לדעתך לקחת את חלק 7 זה קל יותר מהאופציה השנייה?`
3. `זאת אומרת שזה בסדר להמשיך עם ההוט ספוט הזה אבל פשוט צריך להיות מדויקים בדוח?`
4. `טוב אז עכשיו נוכל להתחיל את העבודה שלנו?`
5. `איך אני אדע אם עשית עבודה טובה אני פשוט לא מכיר מספיק את החומר בשביל להבין מה עשית`
6. `סבבה יש לך אישור to proceed`

The surrounding instructions established that Part 7 should implement one
hardware accelerator for Pyflate, including the RTL, testbench, HW/SW
interface, block diagram, expected performance, and trade-offs, while the
partner completes the software optimizations.

Codex was used to inspect the repository and assignment, interpret the
profiling data without double-counting cumulative times, design the canonical
Huffman accelerator, write the SystemVerilog modules and self-checking
testbench, execute lint and simulation, and draft the documentation. The design
was refined after inspection of the actual Pyflate BZip2 code showed that it
uses two to six Huffman groups and changes the selected group every 50 symbols;
the final RTL therefore contains six resident table banks.

Verification performed by the AI tool:

- SystemVerilog lint with Verilator 5.49, with no reported warnings or errors.
- Self-checking simulation covering successful decoding, a byte-boundary case,
  underflow/refill, multiple table banks, an invalid code, and an invalid table.
- Differential simulation of the complete real Pyflate Huffman workload:
  148,271 symbols, six table banks, a mid-byte handoff, and zero mismatches
  against the Python reference.
- Generic Yosys elaboration confirming seven inferred memories with 20,292
  table-storage bits.
- Manual comparison of the architecture against the Part 7 requirements in the
  supplied project PDF.

The authors remain responsible for understanding the implementation, rerunning
the official profile and benchmarks inside the course QEMU environment, and
reviewing all claims before submission.
