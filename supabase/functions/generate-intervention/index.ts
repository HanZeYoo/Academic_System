import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const {
      studentName,
      gradeLevel,
      section,
      schoolYear,
      gradingPeriod,
      overallAverage,
      attendancePercentage,
      riskLevel,
      subjectGrades,
    } = await req.json();

    const apiKey = Deno.env.get('GEMINI_API_KEY');
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY secret is missing');
    }

    const subjectBreakdown = subjectGrades
      .map((s: any) => {
        const parts = [`• ${s.subjectName}: ${s.grade?.toFixed(1) ?? 'N/A'} (${s.status ?? 'N/A'})`];
        if (s.wwAvg != null) parts.push(`  - Written Works: ${s.wwAvg.toFixed(1)}%`);
        if (s.ptAvg != null) parts.push(`  - Performance Tasks: ${s.ptAvg.toFixed(1)}%`);
        if (s.teAvg != null) parts.push(`  - Quarterly Assessment: ${s.teAvg.toFixed(1)}%`);
        return parts.join('\n');
      })
      .join('\n');

    const failingSubjects = subjectGrades
      .filter((s: any) => s.grade > 0 && s.grade < 75)
      .map((s: any) => s.subjectName);

    const prompt = `
You are an experienced academic guidance counselor in a Philippine K-12 school.
Your task is to generate a clear, compassionate, and ACTIONABLE academic intervention plan for a parent.

--- STUDENT PROFILE ---
Name: ${studentName}
Grade Level: ${gradeLevel} | Section: ${section}
School Year: ${schoolYear} | Grading Period: ${gradingPeriod}
Overall Average: ${overallAverage?.toFixed(2) ?? 'N/A'}
Attendance Rate: ${attendancePercentage?.toFixed(1) ?? 'N/A'}%
Risk Level: ${riskLevel}

--- SUBJECT PERFORMANCE ---
${subjectBreakdown}

--- FAILING SUBJECTS ---
${failingSubjects.length > 0 ? failingSubjects.join(', ') : 'None'}

---

INSTRUCTIONS:
1. Write the intervention plan DIRECTLY to the parent. Be empathetic but factual.
2. DO NOT output placeholder text like "(2-3 sentences summarizing...)". You must REPLACE those instructions with the actual content you generate!
3. Structure your response with these exact markdown headings:

### Academic Overview
[Write a comprehensive 2-3 sentence summary of the child's current academic standing based on the data provided.]

### Key Areas of Concern
[Write 2-4 specific, data-backed observations. E.g. "Your child scored 65% in Written Works for Science..."]

### Recommended Home Intervention Strategies
[Provide 4-6 highly specific and practical strategies the parent can do at home. Use bullet points.]

### Communication with Teachers
[Write 1-2 sentences advising the parent on what specific questions to ask the teacher.]

### Encouragement
[Write 1 warm, motivating sentence to close the plan in a supportive tone.]

IMPORTANT: Do not copy the bracketed text. Keep the entire response concise and straight to the point to avoid truncation. Write the actual personalized content for each section! Keep the tone warm, professional, and encouraging. Use conversational Taglish (Tagalog-English) to make it more relatable and approachable for Filipino parents (e.g., "Maaari po nating tulungan si...", "We recommend setting a schedule...").
`.trim();

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent?key=${apiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          temperature: 0.4,
        },
        safetySettings: [
          { category: 'HARM_CATEGORY_HARASSMENT', threshold: 'BLOCK_NONE' },
          { category: 'HARM_CATEGORY_HATE_SPEECH', threshold: 'BLOCK_NONE' },
        ],
      }),
    });

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      throw new Error(`Gemini API error: ${errText}`);
    }

    const geminiData = await geminiResponse.json();
    const planText: string = geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

    if (!planText) {
      throw new Error('Gemini returned an empty response.');
    }

    return new Response(
      JSON.stringify({ success: true, plan: planText }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );
  } catch (error: any) {
    console.error('generate-intervention error:', error);
    return new Response(
      JSON.stringify({ error: error.message ?? 'Unknown error' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
