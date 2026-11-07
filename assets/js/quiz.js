(() => {
  "use strict";

  const form = document.getElementById("fox-quiz");
  const questions = Array.from(form.querySelectorAll(".quiz-question"));
  const progress = document.getElementById("quiz-progress");
  const results = document.getElementById("quiz-results");
  const score = document.getElementById("quiz-score");

  function clearResults() {
    results.hidden = true;
    score.textContent = "";
    questions.forEach((question) => {
      question.querySelector(".quiz-feedback").hidden = true;
      question.querySelector(".quiz-verdict").textContent = "";
      question.removeAttribute("data-result");
      question.querySelectorAll(".quiz-option").forEach((option) => {
        option.removeAttribute("data-answer-result");
        const status = option.querySelector(".quiz-answer-status");
        status.hidden = true;
        status.textContent = "";
      });
    });
  }

  function updateProgress() {
    const answered = questions.filter((question) => question.querySelector("input:checked")).length;
    progress.textContent = `${answered} of ${questions.length} questions answered. ${answered === questions.length ? "Ready to check your discoveries!" : "Follow your curiosity!"}`;
  }

  form.addEventListener("change", () => {
    clearResults();
    updateProgress();
  });

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    if (!form.reportValidity()) {
      return;
    }

    let correct = 0;
    questions.forEach((question) => {
      const answer = question.querySelector("input:checked");
      const isCorrect = answer.value === question.dataset.answer;
      if (isCorrect) {
        correct += 1;
      }
      question.dataset.result = isCorrect ? "correct" : "discover";
      question.querySelector(".quiz-verdict").textContent = isCorrect ? "Correct! You spotted it." : "Not quite. Here's the correct answer.";
      question.querySelectorAll(".quiz-option").forEach((option) => {
        const input = option.querySelector("input");
        const status = option.querySelector(".quiz-answer-status");
        if (input.value === question.dataset.answer) {
          option.dataset.answerResult = "correct";
          status.textContent = input.checked ? "Your answer - correct" : "Correct answer";
          status.hidden = false;
        } else if (input.checked) {
          option.dataset.answerResult = "incorrect";
          status.textContent = "Your answer - incorrect";
          status.hidden = false;
        }
      });
      question.querySelector(".quiz-feedback").hidden = false;
    });

    const message = correct === questions.length
      ? "Top-notch tracking, fox expert!"
      : correct >= questions.length / 2
        ? "Good detective work! There are more clues to explore."
        : "Your fox adventure is just beginning. Every clue helps!";
    score.textContent = `${correct} out of ${questions.length} correct. ${message}`;
    results.hidden = false;
    results.focus();
  });

  form.addEventListener("reset", () => {
    clearResults();
    progress.textContent = `0 of ${questions.length} questions answered. Follow your curiosity!`;
    questions[0].querySelector("input").focus();
  });

  updateProgress();
  form.querySelector(".quiz-actions").hidden = false;
})();
