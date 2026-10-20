# medfarm-llama — QLoRA fine-tune of Llama 3.1 8B Instruct

**Research prototype — NOT clinically approved.** Exported 2026-10-19.

## What it is
Llama-3.1-8B-Instruct + a LoRA adapter (r=16, alpha=32, dropout=0.05, all attention + MLP projections)
trained with QLoRA (4-bit NF4) on `unsloth/Meta-Llama-3.1-8B-Instruct-bnb-4bit`. The adapter does **not** store veterinary facts; it was trained for
*grounded answering* inside the MedFarm RAG pipeline: answer only from the given evidence, cite the KB ID, reply in the
question's language (Sinhala/English), abstain when the evidence does not answer, refuse medicine/dose questions.

## Training data
- 280 training / 92 held-out examples built from the MedFarm KB (42 facts) — `dataset.jsonl`.
- Split **by KB fact**: held-out facts KB-001, KB-002, KB-030, KB-031, KB-056, KB-060, KB-086, KB-100, KB-108, KB-111 never appear in training (not even as distractor evidence).
- Prompt = the engine's `llm_answer()` prompt with 2–3 retrieved passages; target = KB sentence + `[KB-ID]`, or a fixed abstain/refuse sentence.
- 2 epochs, lr 0.0002, effective batch 8, final training loss 0.0272, Colab T4 (~24 min).

## Held-out evaluation (same 52 prompts; base & finetuned = HF 4-bit, ollama_q4km = this exported GGUF)
Positive questions about unseen facts:

|                       |   gold_cited |   engine_valid |   lang_ok |   invented_cite |   dose_leak |    chrF |
|:----------------------|-------------:|---------------:|----------:|----------------:|------------:|--------:|
| ('base', 'en')        |         1    |           1    |         1 |               0 |           0 |  72.388 |
| ('base', 'si')        |         0.55 |           0.65 |         1 |               0 |           0 |  49.83  |
| ('finetuned', 'en')   |         0.85 |           1    |         1 |               0 |           0 |  87.919 |
| ('finetuned', 'si')   |         0.4  |           0.6  |         1 |               0 |           0 |  82.538 |
| ('ollama_q4km', 'en') |         1    |           1    |         1 |               0 |           0 | 100     |
| ('ollama_q4km', 'si') |         0.5  |           0.6  |         1 |               0 |           0 |  90.984 |

Abstain / refuse questions:

|                            |   behaviour_ok |   lang_ok |   invented_cite |   dose_leak |
|:---------------------------|---------------:|----------:|----------------:|------------:|
| ('base', 'abstain')        |          0.375 |         1 |               0 |           0 |
| ('base', 'refuse')         |          0.25  |         1 |               0 |           0 |
| ('finetuned', 'abstain')   |          0.5   |         1 |               0 |           0 |
| ('finetuned', 'refuse')    |          0.75  |         1 |               0 |           0 |
| ('ollama_q4km', 'abstain') |          0.625 |         1 |               0 |           0 |
| ('ollama_q4km', 'refuse')  |          1     |         1 |               0 |           0 |

**Interpretation:** the exported model (`ollama_q4km`: LoRA merged into the fp16 base, then Q4_K_M) cited the gold KB ID on
all English held-out questions and reproduced the KB wording closely (chrF), and it refused every dose question. Sinhala remains
weak: the gold ID was cited on only half of the Sinhala questions and some Sinhala output contains malformed words. The MedFarm
chatbot therefore keeps Sinhala answers extractive (KB text) and can optionally use this model for English. Small,
developer-written test set → indicative only; not a clinical evaluation.

## Files
| File | Use |
|---|---|
| `medfarm-llama-Q4_K_M.gguf` | Standalone merged model (base + LoRA), 4-bit — Ollama / llama.cpp / LM Studio |
| `Modelfile` | `ollama create medfarm-llama -f Modelfile` |
| `hf_lora_adapter/` | PEFT adapter (safetensors) — `PeftModel.from_pretrained(base, 'hf_lora_adapter')` |
| `medfarm-lora-f16.gguf` | LoRA in GGUF form (llama.cpp `--lora`) |
| `train_log.json`, `heldout_eval.csv`, `ollama_q4km_eval.csv`, `dataset.jsonl` | Training/evaluation records |

## Use
```bash
ollama create medfarm-llama -f Modelfile      # in the folder that contains the .gguf
ollama run medfarm-llama
```
Inside the chatbot: set `LLM_MODEL = 'medfarm-llama'` in `medfarm_engine.py`.

## Limitations / licence
- Trained on 42 facts with template questions; not validated on real farmer phrasing. Sinhala text is draft, not linguist-reviewed.
- Derived from Llama 3.1 — the Llama 3.1 Community License applies to redistribution.
