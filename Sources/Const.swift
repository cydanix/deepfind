

let MlxCommunityRepo = "mlx-community"

let Gemma_2_9b_it_4bit = "gemma-2-9b-it-4bit"
let Meta_Llama_3_8B_Instruct_4bit = "Meta-Llama-3-8B-Instruct-4bit"
let DeepSeek_R1_Distill_Qwen_7B_4bit = "DeepSeek-R1-Distill-Qwen-7B-4bit"
let Mistral_7B_Instruct_v0_3_4bit = "Mistral-7B-Instruct-v0.3-4bit"
let Qwen_3_8B_4bit = "Qwen-3-8B-4bit"
let Phi_3_5_mini_instruct_4bit = "Phi-3.5-mini-instruct-4bit"
let Gemma_2_2b_it_4bit = "gemma-2-2b-it-4bit"
let Qwen2_5_1_5B_Instruct_4bit = "Qwen2.5-1.5B-Instruct-4bit"
let Llama_3_2_3B_Instruct_4bit = "Llama-3.2-3B-Instruct-4bit"
let Qwen3_4B_4bit = "Qwen3-4B-4bit"

let TextLLMModelNames = [
    Gemma_2_9b_it_4bit,
    Meta_Llama_3_8B_Instruct_4bit,
    DeepSeek_R1_Distill_Qwen_7B_4bit,
    Mistral_7B_Instruct_v0_3_4bit,
    Qwen_3_8B_4bit,
    Phi_3_5_mini_instruct_4bit,
    Gemma_2_2b_it_4bit,
    Qwen2_5_1_5B_Instruct_4bit,
]

let DeepFindAppDir = "/Applications/DeepFind.app"

let DeepFindSite = "https://deepfind.com"
let DeepFindCompanyName = "Cydanix LLC"

let DeepFindAppName = "DeepFind"

let KiloByte = Int64(1024)
let MegaByte = KiloByte * KiloByte
let GigaByte = MegaByte * KiloByte
let MinimalFreeDiskSpace = GigaByte * Int64(20)

let CurrentLLMModelRepo = MlxCommunityRepo;
let CurrentLLMModelName = Qwen3_4B_4bit;