---
layout: page
title: The Fox Knowledge Quiz
description: Ten questions for curious fox detectives. Test your knowledge, follow the clues, and discover the science behind every answer.
eyebrow: Wesley's field challenge
image: { path: /assets/images/social-quiz.png, width: 1200, height: 630, alt: "The Fox Knowledge Quiz: an illustrated fox beside a field notebook with ten discovery questions." }
---

Can you think like a fox scientist? From tiny toe prints to Arctic winter
coats, every answer is hiding somewhere in our field guide. Keep the
[red fox]({{ '/foxes/red-fox/' | relative_url }}) and
[Arctic fox]({{ '/foxes/arctic-fox/' | relative_url }}) profiles handy:
**looking things up is part of the adventure!**

There is no timer, and mistakes are discoveries in disguise. Choose one answer
for each question, then check your score to unlock explanations and a research
trail. Your answers stay in this page: nothing is saved or sent anywhere.

<form id="fox-quiz" aria-label="Fox knowledge quiz">
  <p id="quiz-progress" class="quiz-progress" aria-live="polite" aria-atomic="true">0 of {{ site.data.quiz.size }} questions answered. Follow your curiosity!</p>
  {% for question in site.data.quiz %}
  {% assign question_number = forloop.index %}
  <fieldset class="quiz-question" data-answer="{{ question.answer }}" aria-describedby="quiz-feedback-{{ question_number }}">
	<legend><span class="quiz-number">{{ question_number }} / {{ site.data.quiz.size }}</span> {{ question.question | escape }}</legend>
	{% for option in question.options %}
	<label class="quiz-option" for="quiz-{{ question_number }}-{{ forloop.index }}">
	  <input type="radio" id="quiz-{{ question_number }}-{{ forloop.index }}" name="question-{{ question_number }}" value="{{ forloop.index }}" required>
	  <span>{{ option | escape }}<span class="quiz-answer-status" hidden></span></span>
	</label>
	{% endfor %}
	<div class="quiz-feedback" id="quiz-feedback-{{ question_number }}" hidden>
	  <p class="quiz-verdict"></p>
	  <p>{{ question.explanation | escape }}</p>
	  <p><a href="{{ question.source | relative_url }}">{{ question.source_label | escape }} &rarr;</a></p>
	</div>
  </fieldset>
  {% endfor %}
  <div class="quiz-actions" hidden>
	<button class="button" type="submit">Check my answers</button>
	<button class="quiz-reset" type="reset">Try again</button>
  </div>
  <section id="quiz-results" class="quiz-results" aria-labelledby="quiz-result-heading" tabindex="-1" hidden>
	<h2 id="quiz-result-heading">Your field report</h2>
	<p id="quiz-score"></p>
	<p>Every answer above now has an explanation and a trail back to the field guide. Revisit a clue, change an answer, or try again. Scientists keep learning!</p>
  </section>
</form>

<noscript>
  <p>Automatic scoring needs JavaScript, but you can still play! Choose your answers above, then open the answer key below to check your discoveries.</p>
  <details class="wonder-box">
	<summary>Open the fox detective answer key</summary>
	<ol>
	  {% for question in site.data.quiz %}
	  <li>{{ question.explanation | escape }} <a href="{{ question.source | relative_url }}">{{ question.source_label | escape }}</a>.</li>
	  {% endfor %}
	</ol>
  </details>
</noscript>

<nav class="explore-links" aria-label="Keep exploring">
  <a href="{{ '/foxes/' | relative_url }}">&larr; Back to Meet the Foxes</a>
  <a href="{{ '/#our-adventure' | relative_url }}">Back to the den &rarr;</a>
</nav>
<script src="{{ '/assets/js/quiz.js' | relative_url }}" defer></script>
