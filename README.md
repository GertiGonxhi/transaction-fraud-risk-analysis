# Transaction Fraud Risk Analysis  
### SQL + Tableau Behavioral Fraud Study (500K Transactions)

---

📊 **Dashboard Preview**  
![Fraud Dashboard](./tableau/fraud_dashboard_hero.png)

---

## Summary

Analyzed 500,000 credit card transactions to evaluate whether traditional fraud detection signals still work in real-world conditions.

---

## Key Finding

Fraud cannot be reliably detected using:
- Transaction amount
- Merchant category
- Geography
- Authentication strength

Fraud behaves like normal customer activity with hidden behavioral patterns.

---

## Critical Insight

Authentication strength (Chip + PIN) does NOT reduce fraud risk:

- Chip + PIN fraud rate: ~1.59%
- Weak methods: ~1.47%–1.53%

👉 Fraud bypasses traditional security layers.

---

## What Actually Matters

Stronger signals:
- Time-of-day anomalies
- Behavioral deviation from user baseline
- New merchant interactions
- Context combinations (not single rules)

---

## Business Impact

Rule-based fraud systems are insufficient.

Detection must shift to:

> Behavioral risk scoring models instead of static thresholds.

---

## Tools

- MySQL (data analysis)
- Tableau (visualization)

---

## Dashboard

Interactive Tableau Public Dashboard:  
👉 https://public.tableau.com/app/profile/gerti.gonxhi

---

## Outcome

Fraud is not concentrated in obvious segments.  
It is behavior-based, distributed, and subtle.

Traditional banking heuristics fail to isolate it effectively.

---

## Contact

**Gerti Gonxhi**

- Email: Geertt.sh@icloud.com  
- LinkedIn: https://linkedin.com/in/gerti-gonxhi-40539a391  
- GitHub: https://github.com/GertiGonxhi  
