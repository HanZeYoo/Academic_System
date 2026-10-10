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
Use conversational Taglish (Tagalog-English) to make it highly relatable to Filipino parents. 
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
    contents.push({ role: 'model', parts: [{ text: 'Naintindihan ko po. Handa na akong sagutin ang inyong mga katanungan tungkol sa Intervention Plan ng inyong anak.' }] });

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

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: contents,
        generationConfig: {
          temperature: 0.5,
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
        ],
      }),
    });

    if (!geminiResponse.ok) {
      const err = await geminiResponse.text();
      throw new Error(`Gemini API error: ${err}`);
    }

    const geminiData = await geminiResponse.json();
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
