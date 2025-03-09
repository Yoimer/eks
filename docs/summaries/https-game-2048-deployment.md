# AWS Route 53 CNAME Records Setup

Two **CNAME records** were necessary for **two separate purposes** in our setup. Let's break it down:

## 1️⃣ First CNAME: Route 53 Subdomain → AWS Load Balancer

### Purpose:
To map your custom domain (`k8slearning.awslaboratorio.com`) to the **ALB** (Application Load Balancer) created in your **stage account**.

### Why?
- Your **ALB** has a dynamically assigned **AWS-managed DNS name** (e.g., `k8s-game2048-game2048-xxxxxxxx.us-east-1.elb.amazonaws.com`).
- You want users to access your service using **`k8slearning.awslaboratorio.com`** instead of the **ugly ALB DNS**.
- A **CNAME record** in **Route 53** points your subdomain to the **ALB**.

### Command to Check (Which We Used)

```bash
dig k8slearning.awslaboratorio.com +short
```

✅ **Expected Output:** The **ALB DNS name**.

## 2️⃣ Second CNAME: ACM Certificate Validation Record

### Purpose: To validate the SSL certificate request in AWS Certificate Manager (ACM) from the stage account.

### Why?
- ACM requires domain validation before issuing a certificate.
Since your domain is managed in a separate AWS account, ACM can’t automatically validate ownership.
- AWS provides a unique CNAME validation record to prove ownership.

### Command to Retrieve the CNAME Validation Record (Which We Used)
```bash
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/abcd1234-5678-90ef-ghij-klmnopqrstuv \
    --query 'Certificate.DomainValidationOptions'
```

✅ **Expected Output: A CNAME record like:**

```json
"ResourceRecord": {
    "Name": "_e4c0e8106cf6075a97179dbf50fedbec.k8slearning.awslaboratorio.com.",
    "Type": "CNAME",
    "Value": "_dcefffce0bf637c36ce3fc0974648376.xlfgrmvvlj.acm-validations.aws."
}
```

###  What We Did:

- We added this record in Route 53 (domain account) so that AWS could verify ownership.
- Once verified, ACM issued the certificate, allowing us to use HTTPS.

### Command to Verify ACM Status (Which We Used)
```bash
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/abcd1234-5678-90ef-ghij-klmnopqrstuv \
    --query 'Certificate.Status'
```

✅ **Expected Output: "ISSUED"**


## Summary:

| CNAME  | Purpose  | Points To  |
|---------|----------|------------|
| **First CNAME** | Connects `k8slearning.awslaboratorio.com` to the **ALB** | `k8s-game2048-game2048-xxxxxxxx.us-east-1.elb.amazonaws.com` |
| **Second CNAME** | Validates ACM SSL certificate ownership | `_dcefffceobf637c36ce3fc0974648376.xlfgrmw1j.acm-validations.aws.` |

---

## Why Did We Need Both?

- If we only had the **first CNAME**, the domain would work but **without HTTPS**.
- If we only had the **second CNAME**, HTTPS would be validated, but **there would be no traffic routing**.

**Both records were required to make HTTPS work properly! ✅**


## 📌 Step 2: Add ACM CNAME Validation Record in the Domain Account

Since the **Route 53 hosted zone** is in the **domain account**, you manually added the **CNAME validation record** there.

### 🔹 How You Did It (AWS Console)
1. Logged into the **domain account**.
2. Opened **Route 53 → Hosted Zones**.
3. Selected the hosted zone for **`awslaboratorio.com`**.
4. Clicked **Create Record**.
5. Added a **CNAME record** with the values retrieved from **ACM**:
   - **Name:** `_e4c0e8106cf6075a97179dbf50fedbec.k8slearning.awslaboratorio.com.`
   - **Value:** `_dcefffce0bf637c36ce3fc0974648376.xlfgrmw1j.acm-validations.aws.`
   - **TTL:** `300`
6. Saved the record.

---

### 🔹 How You Verified (AWS CLI)
To check if the CNAME record was correctly propagated, you used:

```bash
dig CNAME _e4c0e8106cf6075a97179dbf50fedbec.k8slearning.awslaboratorio.com
```

✅ **Expected Output:**

```bash
_dcefffce0bf637c36ce3fc0974648376.xlfgrmw1j.acm-validations.aws.
```

---

### 🔹 Checking ACM Certificate Status
After a few minutes, you checked the ACM status using:

```bash
aws acm describe-certificate \
    --certificate-arn arn:aws:acm:us-east-1:XXXXXXXXXXXX:certificate/abcd1234-5678-90ef-ghij-klmnopqrstuv \
    --query 'Certificate.Status'
```

✅ **Expected Output:**

```bash
"ISSUED"
```
## 📌 Step 3: Configure Route 53 to Point to the ALB

Once the certificate was validated, you created a **CNAME record** in the **domain account’s Route 53** to point the **subdomain** to the **ALB**.

### 🔹 How You Did It (AWS Console)
1. In **Route 53 (domain account)**, opened **Hosted Zones**.
2. Clicked **Create Record**.
3. Set **Record Type**: `CNAME`
4. Entered:
   - **Name:** `k8slearning.awslaboratorio.com`
   - **Value:** `k8s-game2048-game2048-1051d6c53b-452388330.us-east-1.elb.amazonaws.com`
   - **TTL:** `300`
5. Saved the record.

### 🔹 How You Verified (AWS CLI)
You checked if the **CNAME record** was correct:

```bash
dig k8slearning.awslaboratorio.com +short
```

✅ **Expected Output:**

```bash
k8s-game2048-game2048-1051d6c53b-452388330.us-east-1.elb.amazonaws.com.
```

If this had returned an **old ALB DNS**, that meant DNS propagation was still **in progress**.
