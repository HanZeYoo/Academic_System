import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { planText, chatHistory, message } = await req.json();

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY is not set');
    }

    // Prepare context instruction
    const systemInstruction = `You are a helpful, empathetic Academic Advisor AI for a Philippine school. 
The parent is asking you questions regarding the following Intervention Plan (and raw scores) generated for their child:
"""
${planText}
"""
Your goal is to answer their questions clearly, simply, and concisely based on the plan and general educational best practices. 

MANDATORY LANGUAGE MATCHING RULE:
- Strictly detect and match the language used by the parent in their prompt:
  * If the parent asks in ENGLISH: Your response MUST be 100% in natural, professional, and empathetic ENGLISH. Do NOT use Tagalog or Taglish.
  * If the parent asks in TAGALOG / FILIPINO: Your response MUST be 100% in polite, supportive TAGALOG / FILIPINO (using "po" and "opo"). Do NOT answer in English.
  * If the parent asks in TAGLISH (mixed English and Tagalog): Respond in natural, conversational TAGLISH.
- NEVER reply in Tagalog if the question was written in English.
- NEVER reply in English if the question was written in Tagalog.

IMPORTANT FORMATTING RULES: 
- ALWAYS use Markdown formatting to make your answers easy to read. 
- Use **bold text** for important keywords, subject names, or scores.
- Use bullet points (-) if you are listing more than one item or reason.
- Keep your answers brief (1-3 short paragraphs max). Be direct and supportive.`;

    // Format chat history for Gemini API
    const contents = [];
    
    // Always start with the system instruction masquerading as the user's initial prompt + an "OK" from the model
    // Gemini API requires alternating user/model roles. We simulate setting the context.
    contents.push({ role: 'user', parts: [{ text: systemInstruction }] });
    contents.push({ role: 'model', parts: [{ text: 'Understood. I will assist the parent with their child\'s academic intervention plan and will strictly mirror their language: 100% English if they ask in English, and 100% polite Tagalog/Filipino if they ask in Tagalog.' }] });

    // Append actual chat history
    if (chatHistory && Array.isArray(chatHistory)) {
      for (const msg of chatHistory) {
        contents.push({
          role: msg.role === 'model' ? 'model' : 'user',
          parts: [{ text: msg.text }]
        });
      }
    }

    // Append the new message
    contents.push({ role: 'user', parts: [{ text: message }] });

    const models = [
      'gemini-2.5-flash-lite',
      'gemini-flash-lite-latest',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
      'gemini-flash-latest',
      'gemma-3-27b-it',
    ];
    let geminiData: any = null;
    let lastStatus = 400;
    const attempts: string[] = [];

    for (const model of models) {
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
      const isGemma = model.startsWith('gemma-');

      try {
        const geminiResponse = await fetch(geminiUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          signal: AbortSignal.timeout(10000),
          body: JSON.stringify({
            contents: contents,
            generationConfig: {
              temperature: 0.5,
              maxOutputTokens: 768,
            },
            ...(isGemma
              ? {}
              : {
                  safetySettings: [
                    { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
                    { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
                  ],
                }),
          }),
        });

        if (geminiResponse.ok) {
          geminiData = await geminiResponse.json();
          break;
        }

        lastStatus = geminiResponse.status;
        const errText = await geminiResponse.text();
        attempts.push(`${model}->${lastStatus}:${errText.slice(0, 140)}`);
        console.warn(`Model ${model} failed (${lastStatus}): ${errText}`);

        if (lastStatus === 401 || lastStatus === 403) {
          break;
        }
      } catch (fetchErr: any) {
        lastStatus = 504;
        const msg = fetchErr?.message ?? 'Request timed out';
        attempts.push(`${model}->504:${msg}`);
        console.warn(`Model ${model} timed out/errored: ${msg}`);
      }
    }

    if (!geminiData) {
      return new Response(
        JSON.stringify({ error: `Gemini API failed (${lastStatus}): ${attempts.join(' | ')}` }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: lastStatus === 429 ? 429 : 400 }
      );
    }

    const replyText = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!replyText) {
      throw new Error('Empty response from Gemini');
    }

    return new Response(
      JSON.stringify({ reply: replyText }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
