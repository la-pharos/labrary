/* eslint-disable valid-jsdoc */

import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {initializeApp} from "firebase-admin/app";
import {
  getFirestore,
  FieldValue,
  Timestamp,
} from "firebase-admin/firestore";
import {readFileSync} from "fs";
import {resolve} from "path";

import {
  APIException,
  AppStoreServerAPIClient,
  Environment,
  SignedDataVerifier,
} from "@apple/app-store-server-library";

import {google} from "googleapis";
import {getAuth} from "firebase-admin/auth";

initializeApp();

const db = getFirestore();

const applePrivateKey = defineSecret("APPLE_IAP_PRIVATE_KEY");
const appleIssuerId = defineSecret("APPLE_IAP_ISSUER_ID");
const appleKeyId = defineSecret("APPLE_IAP_KEY_ID");
const appleBundleId = defineSecret("APPLE_BUNDLE_ID");
const appleAppId = defineSecret("APPLE_APP_ID");

const appleProductId = "labrary_premium_monthly";
const googleProductId = "premium_monthly";
const androidPackageName = "com.la_pharos.labrary";
const googlePlayServiceAccount =
  "google-play-subscription@la-pharos.iam.gserviceaccount.com";

type AppleConfig = {
  privateKey: string;
  issuerId: string;
  keyId: string;
  bundleId: string;
  appAppleId: number;
  rootCertificates: Buffer[];
};

type AppleLookupResult = {
  environment: Environment;
  statusResponse: Awaited<
    ReturnType<AppStoreServerAPIClient["getAllSubscriptionStatuses"]>
  >;
};

type ResolvedSubscription = {
  environment: Environment;
  status: number | null;
  active: boolean;
  productId: string;
  transactionId: string | null;
  originalTransactionId: string;
  expiresDateMs: number | null;
  revocationDateMs: number | null;
};

type ResolvedGoogleSubscription = {
  active: boolean;
  productId: string;
  purchaseToken: string;
  expiryTimeMs: number | null;
  subscriptionState: string | null;
  latestOrderId: string | null;
  acknowledgementState: string | null;
};

type AppleClaimResult = {
  previousUid: string | null;
};

/**
 * 닉네임을 Firestore 문서 ID로 사용하기 위해 정규화한다.
 * 영문은 대소문자를 구분하지 않는다.
 */
function normalizeNickname(nickname: string): string {
  return nickname.trim().toLowerCase();
}

const NICKNAME_ALREADY_EXISTS =
  "NICKNAME_ALREADY_EXISTS";

const USER_NOT_FOUND =
  "USER_NOT_FOUND";

const reservedNicknameExact = new Set([
  "운영자",
  "관리자",
  "공식",
  "어드민",
  "admin",
  "administrator",
  "manager",
  "support",
  "official",
  "labrary",
  "라브러리",
]);

const reservedNicknameKeywords = [
  "labrary운영자",
  "labrary관리자",
  "labrary공식",
  "라브러리운영자",
  "라브러리관리자",
  "라브러리공식",
];

/**
 * 운영자 사칭 등에 사용될 수 있는 예약 닉네임인지 확인한다.
 *
 * @param {string} nickname 확인할 닉네임
 * @return {boolean} 예약 닉네임이면 true
 */
function isReservedNickname(nickname: string): boolean {
  const normalized = normalizeNickname(nickname);

  if (reservedNicknameExact.has(normalized)) {
    return true;
  }

  return reservedNicknameKeywords.some(
    (keyword) => normalized.includes(keyword),
  );
}

/**
 * Firebase Authentication에서 이메일 중복 여부를 확인한다.
 */
export const checkEmailAvailability = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const rawEmail = request.data?.email;

    if (typeof rawEmail !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "이메일이 올바르지 않습니다.",
      );
    }

    const email = rawEmail.trim().toLowerCase();

    const emailRegex =
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailRegex.test(email)) {
      throw new HttpsError(
        "invalid-argument",
        "올바른 이메일 형식이 아닙니다.",
      );
    }

    try {
      await getAuth().getUserByEmail(email);

      // 사용자를 찾았으므로 이미 사용 중
      return {
        available: false,
      };
    } catch (error) {
      const errorCode =
        typeof error === "object" &&
        error !== null &&
        "code" in error ?
          String(
            (error as {code?: unknown}).code,
          ) :
          null;

      if (errorCode === "auth/user-not-found") {
        return {
          available: true,
        };
      }

      console.error(
        "이메일 중복확인 실패",
        error,
      );

      throw new HttpsError(
        "internal",
        "이메일 중복확인 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * nicknames 컬렉션에서 닉네임 중복 여부를 확인한다.
 */
export const checkNicknameAvailability = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const rawNickname = request.data?.nickname;

    if (typeof rawNickname !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "닉네임이 올바르지 않습니다.",
      );
    }

    const nickname = rawNickname.trim();
    const nicknameRegex =
      /^[가-힣a-zA-Z0-9]{2,12}$/;

    if (!nicknameRegex.test(nickname)) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.",
      );
    }

    if (isReservedNickname(nickname)) {
      throw new HttpsError(
        "permission-denied",
        "사용할 수 없는 닉네임입니다.",
      );
    }

    const nicknameId =
      normalizeNickname(nickname);

    const nicknameSnapshot = await db
      .collection("nicknames")
      .doc(nicknameId)
      .get();

    return {
      available: !nicknameSnapshot.exists,
    };
  },
);

/**
 * 회원가입 완료 시 닉네임을 최종 선점한다.
 * 트랜잭션을 사용해 동시에 같은 닉네임이 등록되는 것을 막는다.
 */
export const claimNickname = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const uid = request.auth.uid;
    const rawNickname = request.data?.nickname;

    if (typeof rawNickname !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "닉네임이 올바르지 않습니다.",
      );
    }

    const nickname = rawNickname.trim();
    const nicknameRegex =
      /^[가-힣a-zA-Z0-9]{2,12}$/;

    if (!nicknameRegex.test(nickname)) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.",
      );
    }

    if (isReservedNickname(nickname)) {
      throw new HttpsError(
        "permission-denied",
        "사용할 수 없는 닉네임입니다.",
      );
    }

    const nicknameId =
      normalizeNickname(nickname);

    const nicknameRef = db
      .collection("nicknames")
      .doc(nicknameId);

    try {
      await db.runTransaction(async (transaction) => {
        const snapshot =
          await transaction.get(nicknameRef);

        if (snapshot.exists) {
          const existingUid =
            snapshot.data()?.uid;

          if (existingUid === uid) {
            return;
          }

          throw new Error(NICKNAME_ALREADY_EXISTS);
        }

        transaction.create(
          nicknameRef,
          {
            uid,
            nickname,
            normalizedNickname: nicknameId,
            createdAt:
              FieldValue.serverTimestamp(),
          },
        );
      });
    } catch (error) {
      const errorText =
        error instanceof Error ?
          error.message :
          String(error);

      if (errorText.includes(NICKNAME_ALREADY_EXISTS)) {
        throw new HttpsError(
          "already-exists",
          "이미 사용 중인 닉네임입니다.",
        );
      }

      console.error(
        "claimNickname transaction failed:",
        error,
      );

      throw new HttpsError(
        "internal",
        "닉네임 등록 중 오류가 발생했습니다.",
      );
    }

    return {
      success: true,
      nickname,
      normalizedNickname: nicknameId,
    };
  },
);

/**
 * 닉네임으로 사용자를 검색한다.
 * 친구 검색에 필요한 최소 프로필 정보만 반환한다.
 */
export const searchUserByNickname = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const requesterUid = request.auth.uid;

    const rawNickname = request.data?.nickname;

    if (typeof rawNickname !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "닉네임이 올바르지 않습니다.",
      );
    }

    const nickname = rawNickname.trim();

    if (nickname.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "검색할 닉네임을 입력해주세요.",
      );
    }

    const normalizedNickname =
      normalizeNickname(nickname);

    const nicknameSnapshot = await db
      .collection("nicknames")
      .doc(normalizedNickname)
      .get();

    if (!nicknameSnapshot.exists) {
      return {
        found: false,
      };
    }

    const targetUid =
      nicknameSnapshot.data()?.uid;

    if (
      typeof targetUid !== "string" ||
      targetUid.length === 0
    ) {
      return {
        found: false,
      };
    }

    // 자기 자신은 친구 검색 결과에서 제외
    if (targetUid === requesterUid) {
      return {
        found: false,
        isSelf: true,
      };
    }

    const userSnapshot = await db
      .collection("users")
      .doc(targetUid)
      .get();

    if (!userSnapshot.exists) {
      return {
        found: false,
      };
    }

    const userData = userSnapshot.data();

    return {
      found: true,
      user: {
        uid: targetUid,
        nickname:
          typeof userData?.nickname === "string" ?
            userData.nickname :
            "",
        bio:
          typeof userData?.bio === "string" ?
            userData.bio :
            "",
        profileImageUrl:
          typeof userData?.profileImageUrl === "string" ?
            userData.profileImageUrl :
            "",
      },
    };
  },
);

/**
 * 친구 요청을 보낸다.
 *
 * friendRequests/{두 UID의 정렬된 조합}
 * 형태로 저장하여 같은 두 사용자 사이에
 * 중복 요청이 생성되지 않도록 한다.
 */
export const sendFriendRequest = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const fromUid = request.auth.uid;

    const rawToUid = request.data?.toUid;

    if (
      typeof rawToUid !== "string" ||
      rawToUid.trim().length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "친구 요청 대상이 올바르지 않습니다.",
      );
    }

    const toUid = rawToUid.trim();

    // 자기 자신에게 요청 불가
    if (fromUid === toUid) {
      throw new HttpsError(
        "failed-precondition",
        "자기 자신에게 친구 요청을 보낼 수 없습니다.",
      );
    }

    // 요청 대상 사용자가 실제 존재하는지 확인
    const targetUserRef = db
      .collection("users")
      .doc(toUid);

    const targetUserSnapshot =
      await targetUserRef.get();

    if (!targetUserSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "사용자를 찾을 수 없습니다.",
      );
    }

    // 두 UID를 정렬하여 두 사람 사이에
    // 항상 하나의 friendRequest 문서만 존재하도록 한다.
    const pairIds = [fromUid, toUid].sort();

    const requestId =
      `${pairIds[0]}_${pairIds[1]}`;

    const friendRequestRef = db
      .collection("friendRequests")
      .doc(requestId);

    // 이미 친구인지 확인
    const myFriendRef = db
      .collection("users")
      .doc(fromUid)
      .collection("friends")
      .doc(toUid);

    try {
      await db.runTransaction(
        async (transaction) => {
          const [
            friendRequestSnapshot,
            myFriendSnapshot,
          ] = await Promise.all([
            transaction.get(friendRequestRef),
            transaction.get(myFriendRef),
          ]);

          // 이미 친구
          if (myFriendSnapshot.exists) {
            throw new HttpsError(
              "already-exists",
              "이미 친구인 사용자입니다.",
            );
          }

          // 두 사용자 사이에 요청이 이미 존재
          if (friendRequestSnapshot.exists) {
            const requestData =
              friendRequestSnapshot.data();

            const status =
              requestData?.status;

            const existingFromUid =
              requestData?.fromUid;

            const existingToUid =
              requestData?.toUid;

            if (status === "pending") {
              // 내가 이미 보낸 요청
              if (
                existingFromUid === fromUid &&
                existingToUid === toUid
              ) {
                throw new HttpsError(
                  "already-exists",
                  "이미 친구 요청을 보냈습니다.",
                );
              }

              // 상대가 나에게 이미 요청함
              if (
                existingFromUid === toUid &&
                existingToUid === fromUid
              ) {
                throw new HttpsError(
                  "failed-precondition",
                  "상대방이 이미 친구 요청을 보냈습니다.",
                );
              }
            }

            // 과거 거절/취소 등의 문서가 있다면
            // 새로운 요청으로 덮어쓴다.
            transaction.set(
              friendRequestRef,
              {
                fromUid,
                toUid,
                status: "pending",
                createdAt:
                  FieldValue.serverTimestamp(),
                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
            );

            return;
          }

          // 최초 친구 요청
          transaction.create(
            friendRequestRef,
            {
              fromUid,
              toUid,
              status: "pending",
              createdAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "sendFriendRequest failed:",
        {
          error,
          fromUid,
          toUid,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 요청을 보내는 중 오류가 발생했습니다.",
      );
    }

    // =====================================================
    // 친구 요청 알림 생성
    // =====================================================
    const senderSnapshot = await db
      .collection("users")
      .doc(fromUid)
      .get();

    const senderData = senderSnapshot.data();

    const senderNickname =
      typeof senderData?.nickname === "string" ?
        senderData.nickname :
        "친구";

    const notificationRef = db
      .collection("users")
      .doc(toUid)
      .collection("notifications")
      .doc();

    await notificationRef.set({
      type: "friend_request",

      title: "새로운 친구 요청",
      body: `${senderNickname}님이 친구 요청을 보냈어요.`,

      actorUid: fromUid,
      actorNickname: senderNickname,

      referenceId: requestId,

      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      requestId,
    };
  },
);

/**
 * 받은 친구 요청을 수락한다.
 *
 * 요청을 받은 사용자만 수락할 수 있으며,
 * 수락 시 양쪽 users/{uid}/friends/{friendUid}
 * 문서를 동시에 생성한다.
 */
export const acceptFriendRequest = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const currentUid = request.auth.uid;

    const rawRequestId =
      request.data?.requestId;

    if (
      typeof rawRequestId !== "string" ||
      rawRequestId.trim().length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "친구 요청 정보가 올바르지 않습니다.",
      );
    }

    const requestId =
      rawRequestId.trim();

    const friendRequestRef = db
      .collection("friendRequests")
      .doc(requestId);

    // =====================================================
    // 친구 요청 정보 미리 확인
    // =====================================================
    const initialRequestSnapshot =
      await friendRequestRef.get();

    if (!initialRequestSnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "친구 요청을 찾을 수 없습니다.",
      );
    }

    const initialRequestData =
      initialRequestSnapshot.data();

    const requesterUid =
      initialRequestData?.fromUid;

    const receiverUid =
      initialRequestData?.toUid;

    if (
      typeof requesterUid !== "string" ||
      typeof receiverUid !== "string"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "친구 요청 정보가 올바르지 않습니다.",
      );
    }

    if (receiverUid !== currentUid) {
      throw new HttpsError(
        "permission-denied",
        "이 친구 요청을 수락할 권한이 없습니다.",
      );
    }

    // =====================================================
    // 양쪽 프로필 조회
    // =====================================================
    const [
      requesterUserSnapshot,
      receiverUserSnapshot,
    ] = await Promise.all([
      db
        .collection("users")
        .doc(requesterUid)
        .get(),

      db
        .collection("users")
        .doc(receiverUid)
        .get(),
    ]);

    const requesterUserData =
      requesterUserSnapshot.data();

    const receiverUserData =
      receiverUserSnapshot.data();

    const requesterNickname =
      typeof requesterUserData?.nickname === "string" ?
        requesterUserData.nickname :
        "";

    const requesterBio =
      typeof requesterUserData?.bio === "string" ?
        requesterUserData.bio :
        "";

    const requesterProfileImageUrl =
      typeof requesterUserData?.profileImageUrl === "string" ?
        requesterUserData.profileImageUrl :
        "";

    const receiverNickname =
      typeof receiverUserData?.nickname === "string" ?
        receiverUserData.nickname :
        "";

    const receiverBio =
      typeof receiverUserData?.bio === "string" ?
        receiverUserData.bio :
        "";

    const receiverProfileImageUrl =
      typeof receiverUserData?.profileImageUrl === "string" ?
        receiverUserData.profileImageUrl :
        "";

    try {
      await db.runTransaction(
        async (transaction) => {
          const requestSnapshot =
            await transaction.get(friendRequestRef);

          if (!requestSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "친구 요청을 찾을 수 없습니다.",
            );
          }

          const requestData =
            requestSnapshot.data();

          const fromUid =
            requestData?.fromUid;

          const toUid =
            requestData?.toUid;

          const status =
            requestData?.status;

          if (
            fromUid !== requesterUid ||
            toUid !== receiverUid
          ) {
            throw new HttpsError(
              "aborted",
              "친구 요청 정보가 변경되었습니다.",
            );
          }

          if (toUid !== currentUid) {
            throw new HttpsError(
              "permission-denied",
              "이 친구 요청을 수락할 권한이 없습니다.",
            );
          }

          if (status !== "pending") {
            throw new HttpsError(
              "failed-precondition",
              "이미 처리된 친구 요청입니다.",
            );
          }

          const myFriendRef = db
            .collection("users")
            .doc(receiverUid)
            .collection("friends")
            .doc(requesterUid);

          const otherFriendRef = db
            .collection("users")
            .doc(requesterUid)
            .collection("friends")
            .doc(receiverUid);

          const [
            myFriendSnapshot,
            otherFriendSnapshot,
          ] = await Promise.all([
            transaction.get(myFriendRef),
            transaction.get(otherFriendRef),
          ]);

          // 내가 보는 상대 프로필
          transaction.set(
            myFriendRef,
            {
              friendUid: requesterUid,

              nickname: requesterNickname,
              bio: requesterBio,
              profileImageUrl:
                requesterProfileImageUrl,

              createdAt:
                myFriendSnapshot.exists ?
                  myFriendSnapshot.data()?.createdAt ??
                    FieldValue.serverTimestamp() :
                  FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          // 상대가 보는 내 프로필
          transaction.set(
            otherFriendRef,
            {
              friendUid: receiverUid,

              nickname: receiverNickname,
              bio: receiverBio,
              profileImageUrl:
                receiverProfileImageUrl,

              createdAt:
                otherFriendSnapshot.exists ?
                  otherFriendSnapshot.data()?.createdAt ??
                    FieldValue.serverTimestamp() :
                  FieldValue.serverTimestamp(),

              updatedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          transaction.update(
            friendRequestRef,
            {
              status: "accepted",
              acceptedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "acceptFriendRequest failed:",
        {
          error,
          currentUid,
          requestId,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 요청을 수락하는 중 오류가 발생했습니다.",
      );
    }

    // =====================================================
    // 친구 요청 수락 알림 생성
    // =====================================================
    const notificationRef = db
      .collection("users")
      .doc(requesterUid)
      .collection("notifications")
      .doc();

    await notificationRef.set({
      type: "friend_accepted",
      title: "친구 요청 수락",
      body: `${receiverNickname}님과 친구가 되었어요.`,
      actorUid: receiverUid,
      actorNickname: receiverNickname,
      referenceId: requestId,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
    };
  },
);

/**
 * 받은 친구 요청을 거절한다.
 *
 * 요청을 받은 사용자만 거절할 수 있으며,
 * 거절된 요청은 status를 rejected로 변경해 기록을 남긴다.
 */
export const rejectFriendRequest = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const currentUid = request.auth.uid;

    const rawRequestId =
      request.data?.requestId;

    if (
      typeof rawRequestId !== "string" ||
      rawRequestId.trim().length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "친구 요청 정보가 올바르지 않습니다.",
      );
    }

    const requestId =
      rawRequestId.trim();

    const friendRequestRef = db
      .collection("friendRequests")
      .doc(requestId);

    try {
      await db.runTransaction(
        async (transaction) => {
          const requestSnapshot =
            await transaction.get(friendRequestRef);

          if (!requestSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "친구 요청을 찾을 수 없습니다.",
            );
          }

          const requestData =
            requestSnapshot.data();

          const fromUid =
            requestData?.fromUid;

          const toUid =
            requestData?.toUid;

          const status =
            requestData?.status;

          if (
            typeof fromUid !== "string" ||
            typeof toUid !== "string"
          ) {
            throw new HttpsError(
              "failed-precondition",
              "친구 요청 정보가 올바르지 않습니다.",
            );
          }

          // 요청을 받은 사용자만 거절 가능
          if (toUid !== currentUid) {
            throw new HttpsError(
              "permission-denied",
              "이 친구 요청을 거절할 권한이 없습니다.",
            );
          }

          if (status !== "pending") {
            throw new HttpsError(
              "failed-precondition",
              "이미 처리된 친구 요청입니다.",
            );
          }

          transaction.update(
            friendRequestRef,
            {
              status: "rejected",
              rejectedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "rejectFriendRequest failed:",
        {
          error,
          currentUid,
          requestId,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 요청을 거절하는 중 오류가 발생했습니다.",
      );
    }

    return {
      success: true,
    };
  },
);

/**
 * 내가 받은 pending 상태의 친구 요청 목록을 가져온다.
 *
 * 요청자 프로필의 최소 정보만 함께 반환한다.
 */
export const getReceivedFriendRequests = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const currentUid = request.auth.uid;

    try {
      const requestSnapshot = await db
        .collection("friendRequests")
        .where("toUid", "==", currentUid)
        .where("status", "==", "pending")
        .get();

      if (requestSnapshot.empty) {
        return {
          success: true,
          requests: [],
        };
      }

      const requests = await Promise.all(
        requestSnapshot.docs.map(
          async (requestDoc) => {
            const requestData =
              requestDoc.data();

            const fromUid =
              requestData.fromUid;

            if (
              typeof fromUid !== "string" ||
              fromUid.length === 0
            ) {
              return null;
            }

            const userSnapshot = await db
              .collection("users")
              .doc(fromUid)
              .get();

            if (!userSnapshot.exists) {
              return null;
            }

            const userData =
              userSnapshot.data();

            return {
              requestId: requestDoc.id,
              fromUid,
              nickname:
                typeof userData?.nickname === "string" ?
                  userData.nickname :
                  "",
              bio:
                typeof userData?.bio === "string" ?
                  userData.bio :
                  "",
              profileImageUrl:
                typeof userData?.profileImageUrl === "string" ?
                  userData.profileImageUrl :
                  "",
              createdAt:
                requestData.createdAt ?? null,
            };
          },
        ),
      );

      const filteredRequests =
        requests.filter(
          (item) => item !== null,
        );

      return {
        success: true,
        requests: filteredRequests,
      };
    } catch (error) {
      console.error(
        "getReceivedFriendRequests failed:",
        {
          error,
          currentUid,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 요청 목록을 불러오는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 현재 사용자의 친구 목록을 가져온다.
 *
 * 최신 friend 문서는 프로필 최소 정보를 직접 가지고 있으므로
 * 추가 user 조회 없이 반환한다.
 *
 * 구버전 friend 문서에 프로필 정보가 없다면
 * users/{friendUid}에서 한 번 조회한 뒤 friend 문서에 백필한다.
 */
export const getFriends = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const currentUid = request.auth.uid;

    try {
      const friendsSnapshot = await db
        .collection("users")
        .doc(currentUid)
        .collection("friends")
        .get();

      if (friendsSnapshot.empty) {
        return {
          success: true,
          friends: [],
        };
      }

      const friends = await Promise.all(
        friendsSnapshot.docs.map(
          async (friendDoc) => {
            const friendData =
              friendDoc.data();

            const friendUid =
              typeof friendData.friendUid === "string" ?
                friendData.friendUid :
                friendDoc.id;

            if (friendUid.length === 0) {
              return null;
            }

            // =====================================================
            // 최신 구조: friend 문서에 프로필 정보가 이미 있음
            // =====================================================
            const savedNickname =
              typeof friendData.nickname === "string" ?
                friendData.nickname :
                "";

            const savedBio =
              typeof friendData.bio === "string" ?
                friendData.bio :
                "";

            const savedProfileImageUrl =
              typeof friendData.profileImageUrl === "string" ?
                friendData.profileImageUrl :
                "";

            if (savedNickname.length > 0) {
              return {
                uid: friendUid,
                nickname: savedNickname,
                bio: savedBio,
                profileImageUrl:
                  savedProfileImageUrl,
                friendsSince:
                  friendData.createdAt ?? null,
              };
            }

            // =====================================================
            // 구버전 구조:
            // nickname 등이 없으면 user 문서에서 한 번 가져온다.
            // =====================================================
            const userSnapshot = await db
              .collection("users")
              .doc(friendUid)
              .get();

            if (!userSnapshot.exists) {
              return null;
            }

            const userData =
              userSnapshot.data();

            const nickname =
              typeof userData?.nickname === "string" ?
                userData.nickname :
                "";

            const bio =
              typeof userData?.bio === "string" ?
                userData.bio :
                "";

            const profileImageUrl =
              typeof userData?.profileImageUrl === "string" ?
                userData.profileImageUrl :
                "";

            if (nickname.length === 0) {
              return null;
            }

            // =====================================================
            // 구버전 friend 문서를 최신 구조로 자동 업그레이드
            // =====================================================
            await friendDoc.ref.set(
              {
                friendUid,
                nickname,
                bio,
                profileImageUrl,
                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
            );

            return {
              uid: friendUid,
              nickname,
              bio,
              profileImageUrl,
              friendsSince:
                friendData.createdAt ?? null,
            };
          },
        ),
      );

      const filteredFriends =
        friends
          .filter(
            (friend) => friend !== null,
          );

      return {
        success: true,
        friends: filteredFriends,
      };
    } catch (error) {
      console.error(
        "getFriends failed:",
        {
          error,
          currentUid,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 목록을 불러오는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 친구 프로필 정보를 가져온다.
 *
 * 공개 범위:
 * - 프로필
 * - Reading Overview
 * - 전체 서재
 *
 * 반드시 실제 친구 관계인 경우에만 반환한다.
 */
export const getFriendProfile = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const currentUid =
      request.auth.uid;

    const friendUid =
      typeof request.data?.friendUid === "string" ?
        request.data.friendUid.trim() :
        "";

    if (friendUid.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "친구 정보가 올바르지 않습니다.",
      );
    }

    if (friendUid === currentUid) {
      throw new HttpsError(
        "invalid-argument",
        "자기 자신의 친구 프로필은 조회할 수 없습니다.",
      );
    }

    try {
      // =====================================================
      // 1. 실제 친구 관계인지 확인
      // =====================================================
      const friendshipRef = db
        .collection("users")
        .doc(currentUid)
        .collection("friends")
        .doc(friendUid);

      const friendshipSnapshot =
        await friendshipRef.get();

      if (!friendshipSnapshot.exists) {
        throw new HttpsError(
          "permission-denied",
          "친구만 프로필을 볼 수 있습니다.",
        );
      }

      // =====================================================
      // 2. 친구 기본 프로필 + 서재 + 독서 로그 병렬 조회
      // =====================================================
      const friendRef = db
        .collection("users")
        .doc(friendUid);

      const [
        friendSnapshot,
        savedBooksSnapshot,
        readingLogsSnapshot,
      ] = await Promise.all([
        friendRef.get(),

        friendRef
          .collection("savedBooks")
          .get(),

        friendRef
          .collection("readingTimerLogs")
          .get(),
      ]);

      if (!friendSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "친구 정보를 찾을 수 없습니다.",
        );
      }

      const friendData =
        friendSnapshot.data() ?? {};

      // =====================================================
      // 3. 프로필
      // =====================================================
      const nickname =
        typeof friendData.nickname === "string" ?
          friendData.nickname :
          "";

      const bio =
        typeof friendData.bio === "string" ?
          friendData.bio :
          "";

      const profileImageUrl =
        typeof friendData.profileImageUrl === "string" ?
          friendData.profileImageUrl :
          "";

      // =====================================================
      // 4. 전체 서재
      // createdAt 기준 최근 추가순
      //
      // createdAt이 없는 기존 문서도 누락되지 않도록
      // 전체 문서를 조회한 뒤 서버에서 정렬한다.
      // =====================================================
      const books =
        savedBooksSnapshot.docs
          .map(
            (bookDoc) => {
              const data =
                bookDoc.data();

              const createdAt =
                data.createdAt;

              const createdAtMillis =
                createdAt &&
                typeof createdAt.toMillis === "function" ?
                  createdAt.toMillis() :
                  0;

              return {
                id:
                  typeof data.id === "string" &&
                  data.id.length > 0 ?
                    data.id :
                    bookDoc.id,

                title:
                  typeof data.title === "string" ?
                    data.title :
                    "",

                author:
                  typeof data.author === "string" ?
                    data.author :
                    "",

                imageUrl:
                  typeof data.imageUrl === "string" ?
                    data.imageUrl :
                    "",

                thumbnail:
                  typeof data.thumbnail === "string" ?
                    data.thumbnail :
                    "",

                category:
                  typeof data.category === "string" ?
                    data.category :
                    "",

                publisher:
                  typeof data.publisher === "string" ?
                    data.publisher :
                    "",

                // ==========================================
                // 친구 서재 → 책 등록에 필요한 도서 정보
                // ==========================================
                isbn:
                  typeof data.isbn === "string" ?
                    data.isbn :
                    "",

                description:
                  typeof data.description === "string" ?
                    data.description :
                    "",

                pageCount:
                  typeof data.pageCount === "number" &&
                  Number.isFinite(data.pageCount) ?
                    Math.max(0, Math.floor(data.pageCount)) :
                    0,

                itemId:
                  data.itemId != null ?
                    String(data.itemId) :
                    "",

                // ==========================================
                // YES24 책등 이미지
                // ==========================================
                spineUrl:
                  typeof data.spineUrl === "string" ?
                    data.spineUrl :
                    "",

                // 책등 조회 여부
                spineChecked:
                  data.spineChecked === true,

                // YES24 상품 ID
                yes24ItemId:
                  typeof data.yes24ItemId === "string" ?
                    data.yes24ItemId :
                    "",

                createdAtMillis,
              };
            },
          )
          .sort(
            (a, b) =>
              b.createdAtMillis -
              a.createdAtMillis,
          )
          .map(
            (book) => {
              const {
                createdAtMillis: _,
                ...publicBook
              } = book;

              return publicBook;
            },
          );

      // =====================================================
      // 5. 완독 권수
      // =====================================================
      const totalReadBooks =
        books.filter(
          (book) =>
            book.category === "done",
        ).length;

      // =====================================================
      // 6. 누적 독서시간
      // users/{uid}.totalReadingMinutes 사용
      // =====================================================
      let totalReadingMinutes = 0;

      const rawTotalReadingMinutes =
        friendData.totalReadingMinutes;

      if (
        typeof rawTotalReadingMinutes === "number" &&
        Number.isFinite(
          rawTotalReadingMinutes,
        )
      ) {
        totalReadingMinutes =
          Math.max(
            0,
            Math.floor(
              rawTotalReadingMinutes,
            ),
          );
      }

      // =====================================================
      // 7. 독서한 날짜 수 계산
      // =====================================================
      const readingDateKeys =
        new Set<string>();

      for (
        const logDoc of
        readingLogsSnapshot.docs
      ) {
        const logData =
          logDoc.data();

        const startTime =
          logData.startTime;

        if (
          startTime &&
          typeof startTime.toDate === "function"
        ) {
          const date =
            startTime.toDate();

          const year =
            date.getFullYear();

          const month =
            String(
              date.getMonth() + 1,
            ).padStart(
              2,
              "0",
            );

          const day =
            String(
              date.getDate(),
            ).padStart(
              2,
              "0",
            );

          readingDateKeys.add(
            `${year}-${month}-${day}`,
          );
        }
      }

      const totalReadingDays =
        readingDateKeys.size;

      // =====================================================
      // 8. 최장 연속 독서일 계산
      // =====================================================
      const readingDates =
        Array.from(
          readingDateKeys,
        )
          .map(
            (dateKey) => {
              const parts =
                dateKey.split("-");

              if (
                parts.length !== 3
              ) {
                return null;
              }

              const year =
                Number(
                  parts[0],
                );

              const month =
                Number(
                  parts[1],
                );

              const day =
                Number(
                  parts[2],
                );

              if (
                !Number.isFinite(year) ||
                !Number.isFinite(month) ||
                !Number.isFinite(day)
              ) {
                return null;
              }

              return new Date(
                year,
                month - 1,
                day,
              );
            },
          )
          .filter(
            (date): date is Date =>
              date !== null,
          )
          .sort(
            (a, b) =>
              a.getTime() -
              b.getTime(),
          );

      let longestStreakDays = 0;
      let currentStreak = 0;

      let previousDate:
        Date | null = null;

      for (const date of readingDates) {
        if (previousDate === null) {
          currentStreak = 1;
        } else {
          const previousDay =
            new Date(
              previousDate.getFullYear(),
              previousDate.getMonth(),
              previousDate.getDate(),
            );

          const currentDay =
            new Date(
              date.getFullYear(),
              date.getMonth(),
              date.getDate(),
            );

          const differenceDays =
            Math.round(
              (
                currentDay.getTime() -
                previousDay.getTime()
              ) /
              (
                1000 *
                60 *
                60 *
                24
              ),
            );

          if (
            differenceDays === 1
          ) {
            currentStreak += 1;
          } else {
            currentStreak = 1;
          }
        }

        if (
          currentStreak >
          longestStreakDays
        ) {
          longestStreakDays =
            currentStreak;
        }

        previousDate =
          date;
      }

      // =====================================================
      // 9. 최종 응답
      // =====================================================
      return {
        success: true,

        friend: {
          uid: friendUid,
          nickname,
          bio,
          profileImageUrl,
        },

        overview: {
          totalReadingMinutes,
          totalReadBooks,
          totalReadingDays,
          longestStreakDays,
        },

        books,
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "getFriendProfile failed:",
        {
          error,
          currentUid,
          friendUid,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 프로필을 불러오는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 친구 관계를 삭제한다.
 *
 * 양쪽 users/{uid}/friends/{friendUid}
 * 문서를 동시에 삭제한다.
 */
export const removeFriend = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const currentUid = request.auth.uid;

    const rawFriendUid =
      request.data?.friendUid;

    if (
      typeof rawFriendUid !== "string" ||
      rawFriendUid.trim().length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "친구 정보가 올바르지 않습니다.",
      );
    }

    const friendUid =
      rawFriendUid.trim();

    if (friendUid === currentUid) {
      throw new HttpsError(
        "failed-precondition",
        "자기 자신은 친구에서 삭제할 수 없습니다.",
      );
    }

    const myFriendRef = db
      .collection("users")
      .doc(currentUid)
      .collection("friends")
      .doc(friendUid);

    const otherFriendRef = db
      .collection("users")
      .doc(friendUid)
      .collection("friends")
      .doc(currentUid);

    // 두 UID 조합으로 만들어둔 친구 요청 문서
    const pairIds =
      [currentUid, friendUid].sort();

    const requestId =
      `${pairIds[0]}_${pairIds[1]}`;

    const friendRequestRef = db
      .collection("friendRequests")
      .doc(requestId);

    try {
      await db.runTransaction(
        async (transaction) => {
          const [
            myFriendSnapshot,
            otherFriendSnapshot,
            requestSnapshot,
          ] = await Promise.all([
            transaction.get(myFriendRef),
            transaction.get(otherFriendRef),
            transaction.get(friendRequestRef),
          ]);

          if (
            !myFriendSnapshot.exists &&
            !otherFriendSnapshot.exists
          ) {
            throw new HttpsError(
              "not-found",
              "친구 관계를 찾을 수 없습니다.",
            );
          }

          if (myFriendSnapshot.exists) {
            transaction.delete(
              myFriendRef,
            );
          }

          if (otherFriendSnapshot.exists) {
            transaction.delete(
              otherFriendRef,
            );
          }

          // 기존 요청 이력은 삭제하지 않고
          // 친구 관계가 종료되었다는 상태만 남긴다.
          if (requestSnapshot.exists) {
            transaction.set(
              friendRequestRef,
              {
                status: "removed",
                removedAt:
                  FieldValue.serverTimestamp(),
                updatedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
            );
          }
        },
      );
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "removeFriend failed:",
        {
          error,
          currentUid,
          friendUid,
        },
      );

      throw new HttpsError(
        "internal",
        "친구를 삭제하는 중 오류가 발생했습니다.",
      );
    }

    return {
      success: true,
    };
  },
);

/**
 * Secret과 Apple 루트 인증서를 읽는다.
 */
function loadAppleConfig(): AppleConfig {
  const privateKey = applePrivateKey.value();
  const issuerId = appleIssuerId.value();
  const keyId = appleKeyId.value();
  const bundleId = appleBundleId.value();
  const appAppleId = Number(appleAppId.value());

  if (
    !privateKey ||
    !issuerId ||
    !keyId ||
    !bundleId ||
    !Number.isFinite(appAppleId)
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Apple 서버 설정값이 올바르지 않습니다.",
    );
  }

  const rootCertificates = [
    readFileSync(
      resolve(__dirname, "../certs/AppleRootCA-G2.cer"),
    ),
    readFileSync(
      resolve(__dirname, "../certs/AppleRootCA-G3.cer"),
    ),
  ];

  return {
    privateKey,
    issuerId,
    keyId,
    bundleId,
    appAppleId,
    rootCertificates,
  };
}

/**
 * 환경에 맞는 Apple 서명 검증기를 만든다.
 */
function createVerifier(
  config: AppleConfig,
  environment: Environment,
): SignedDataVerifier {
  return new SignedDataVerifier(
    config.rootCertificates,
    true,
    environment,
    config.bundleId,
    environment === Environment.PRODUCTION ?
      config.appAppleId :
      undefined,
  );
}

/**
 * Apple App Store Server API에서 구독 상태를 조회한다.
 * Production 조회에 실패하면 Sandbox 환경으로 다시 조회한다.
 */
async function getSubscriptionStatusFromApple(
  transactionId: string,
  config: AppleConfig,
): Promise<AppleLookupResult> {
  const productionClient = new AppStoreServerAPIClient(
    config.privateKey,
    config.keyId,
    config.issuerId,
    config.bundleId,
    Environment.PRODUCTION,
  );

  try {
    const statusResponse =
      await productionClient.getAllSubscriptionStatuses(
        transactionId,
      );

    return {
      environment: Environment.PRODUCTION,
      statusResponse,
    };
  } catch (productionError) {
    console.warn(
      "Production 조회 실패, Sandbox 조회를 시도합니다.",
      productionError,
    );
  }

  const sandboxClient = new AppStoreServerAPIClient(
    config.privateKey,
    config.keyId,
    config.issuerId,
    config.bundleId,
    Environment.SANDBOX,
  );

  const statusResponse =
    await sandboxClient.getAllSubscriptionStatuses(
      transactionId,
    );

  return {
    environment: Environment.SANDBOX,
    statusResponse,
  };
}

/**
 * Apple 최신 구독 상태를 조회하고 서명된 거래를 검증한다.
 */
async function resolveSubscription(
  transactionId: string,
  config: AppleConfig,
): Promise<ResolvedSubscription> {
  const {
    environment,
    statusResponse,
  } = await getSubscriptionStatusFromApple(
    transactionId,
    config,
  );

  const verifier = createVerifier(config, environment);

  let selectedTransaction:
    | Awaited<
        ReturnType<
          SignedDataVerifier["verifyAndDecodeTransaction"]
        >
      >
    | null = null;

  let selectedStatus: number | null = null;
  let selectedScore = -1;

  for (const subscriptionGroup of statusResponse.data ?? []) {
    for (
      const latestTransaction
      of subscriptionGroup.lastTransactions ?? []
    ) {
      const signedTransactionInfo =
        latestTransaction.signedTransactionInfo;

      if (!signedTransactionInfo) {
        continue;
      }

      const decodedTransaction =
        await verifier.verifyAndDecodeTransaction(
          signedTransactionInfo,
        );

      if (decodedTransaction.productId !== appleProductId) {
        continue;
      }

      const score =
        typeof decodedTransaction.expiresDate === "number" ?
          decodedTransaction.expiresDate :
          (
            typeof decodedTransaction.purchaseDate === "number" ?
              decodedTransaction.purchaseDate :
              0
          );

      if (score >= selectedScore) {
        selectedScore = score;
        selectedTransaction = decodedTransaction;
        selectedStatus =
          typeof latestTransaction.status === "number" ?
            latestTransaction.status :
            null;
      }
    }
  }

  if (!selectedTransaction) {
    throw new HttpsError(
      "not-found",
      "해당 Apple 구독 상품의 거래를 찾지 못했습니다.",
    );
  }

  const originalTransactionId =
    selectedTransaction.originalTransactionId;

  if (!originalTransactionId) {
    throw new HttpsError(
      "failed-precondition",
      "Apple 원본 거래 ID가 없습니다.",
    );
  }

  const expiresDateMs =
    typeof selectedTransaction.expiresDate === "number" ?
      selectedTransaction.expiresDate :
      null;

  const revocationDateMs =
    typeof selectedTransaction.revocationDate === "number" ?
      selectedTransaction.revocationDate :
      null;

  const isNotExpired =
    expiresDateMs !== null &&
    expiresDateMs > Date.now();

  const isNotRevoked = revocationDateMs === null;

  // 1: active, 2: expired, 3: billing retry,
  // 4: billing grace period, 5: revoked
  const hasValidStatus =
    selectedStatus === 1 ||
    selectedStatus === 4;

  const active =
    hasValidStatus &&
    isNotRevoked &&
    (
      isNotExpired ||
      selectedStatus === 4
    );

  return {
    environment,
    status: selectedStatus,
    active,
    productId:
      selectedTransaction.productId ?? appleProductId,
    transactionId:
      selectedTransaction.transactionId ?? null,
    originalTransactionId,
    expiresDateMs,
    revocationDateMs,
  };
}

/**
 * 사용자의 Firestore 구독 상태를 저장한다.
 */
async function saveSubscriptionStatus(
  uid: string,
  subscription: ResolvedSubscription,
): Promise<void> {
  const subscriptionRef = db
    .collection("users")
    .doc(uid)
    .collection("subscription")
    .doc("status");

  await subscriptionRef.set(
    {
      storeActive: subscription.active,
      storeExpiresAt:
        subscription.expiresDateMs !== null ?
          Timestamp.fromMillis(
            subscription.expiresDateMs,
          ) :
          null,
      storeProductId: subscription.productId,
      storeTransactionId:
        subscription.transactionId,
      storeOriginalTransactionId:
        subscription.originalTransactionId,
      storeEnvironment:
        subscription.environment === Environment.PRODUCTION ?
          "Production" :
          "Sandbox",
      storeStatus: subscription.status,
      storeRevokedAt:
        subscription.revocationDateMs !== null ?
          Timestamp.fromMillis(
            subscription.revocationDateMs,
          ) :
          null,
      storeUpdatedAt: FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );
}

/**
 * Apple 원본 거래 ID와 Firebase UID의 소유 관계를 저장한다.
 * 기존 소유자가 익명 계정이면 현재 UID로 이전하고,
 * 일반 회원 계정이면 이전을 차단한다.
 */
async function claimAppleSubscription(
  uid: string,
  subscription: ResolvedSubscription,
): Promise<AppleClaimResult> {
  const mappingRef = db
    .collection("appleSubscriptions")
    .doc(subscription.originalTransactionId);

  // 1. 현재 연결 상태 확인
  const initialSnapshot = await mappingRef.get();
  const initialExistingUid = initialSnapshot.data()?.uid;

  let transferablePreviousUid: string | null = null;

  if (
    typeof initialExistingUid === "string" &&
    initialExistingUid.length > 0 &&
    initialExistingUid !== uid
  ) {
    try {
      const existingUser =
        await getAuth().getUser(initialExistingUid);

      const existingIsAnonymous =
        existingUser.providerData.length === 0 &&
        !existingUser.email &&
        !existingUser.phoneNumber;

      if (!existingIsAnonymous) {
        throw new HttpsError(
          "permission-denied",
          "이 Apple 구독은 다른 Labrary 계정에 연결되어 있습니다.",
        );
      }

      transferablePreviousUid = initialExistingUid;
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      const errorCode =
        typeof error === "object" &&
        error !== null &&
        "code" in error ?
          String(
            (error as {code?: unknown}).code,
          ) :
          null;

      // 기존 익명 계정이 이미 Firebase Auth에서 삭제된 경우도
      // 정상적인 복원 대상으로 취급
      if (errorCode === "auth/user-not-found") {
        transferablePreviousUid = initialExistingUid;
      } else {
        console.error(
          "기존 Apple 구독 소유자 확인 실패",
          error,
        );

        throw new HttpsError(
          "internal",
          "기존 구독 소유 정보를 확인하지 못했습니다.",
        );
      }
    }
  }

  // 2. transaction에서 최신 상태를 다시 확인하고 소유권 저장
  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(mappingRef);
    const existingUid = snapshot.data()?.uid;

    if (
      typeof existingUid === "string" &&
      existingUid.length > 0 &&
      existingUid !== uid
    ) {
      // 처음 확인한 UID와 달라졌으면 동시 요청 가능성이 있으므로 차단
      if (
        transferablePreviousUid === null ||
        existingUid !== transferablePreviousUid
      ) {
        throw new HttpsError(
          "aborted",
          "구독 소유 정보가 변경되었습니다. 다시 시도해주세요.",
        );
      }
    }

    transaction.set(
      mappingRef,
      {
        uid,
        productId: subscription.productId,
        transactionId: subscription.transactionId,
        originalTransactionId:
          subscription.originalTransactionId,
        environment:
          subscription.environment === Environment.PRODUCTION ?
            "Production" :
            "Sandbox",
        previousUid:
          transferablePreviousUid,
        transferredAt:
          transferablePreviousUid !== null ?
            FieldValue.serverTimestamp() :
            null,
        updatedAt:
          FieldValue.serverTimestamp(),
        createdAt:
          snapshot.exists ?
            snapshot.data()?.createdAt ??
              FieldValue.serverTimestamp() :
            FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );

    return {
      previousUid: transferablePreviousUid,
    };
  });
}

/**
 * Google Play Developer API에서 구독 상태를 조회한다.
 */
async function resolveGoogleSubscription(
  purchaseToken: string,
): Promise<ResolvedGoogleSubscription> {
  const auth = new google.auth.GoogleAuth({
    scopes: [
      "https://www.googleapis.com/auth/androidpublisher",
    ],
  });

  const androidPublisher = google.androidpublisher({
    version: "v3",
    auth,
  });

  const response =
    await androidPublisher.purchases.subscriptionsv2.get({
      packageName: androidPackageName,
      token: purchaseToken,
    });

  const subscription = response.data;

  const matchingLineItems =
    (subscription.lineItems ?? []).filter(
      (lineItem) =>
        lineItem.productId === googleProductId,
    );

  if (matchingLineItems.length === 0) {
    throw new HttpsError(
      "not-found",
      "해당 Google Play 구독 상품을 찾지 못했습니다.",
    );
  }

  let selectedExpiryTimeMs: number | null = null;

  for (const lineItem of matchingLineItems) {
    if (!lineItem.expiryTime) {
      continue;
    }

    const expiryTimeMs = Date.parse(lineItem.expiryTime);

    if (
      Number.isFinite(expiryTimeMs) &&
      (
        selectedExpiryTimeMs === null ||
        expiryTimeMs > selectedExpiryTimeMs
      )
    ) {
      selectedExpiryTimeMs = expiryTimeMs;
    }
  }

  const subscriptionState =
    subscription.subscriptionState ?? null;

  const hasEntitlementState =
    subscriptionState ===
      "SUBSCRIPTION_STATE_ACTIVE" ||
    subscriptionState ===
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD" ||
    subscriptionState ===
      "SUBSCRIPTION_STATE_CANCELED";

  const active =
    hasEntitlementState &&
    selectedExpiryTimeMs !== null &&
    selectedExpiryTimeMs > Date.now();

  return {
    active,
    productId: googleProductId,
    purchaseToken,
    expiryTimeMs: selectedExpiryTimeMs,
    subscriptionState,
    latestOrderId:
      subscription.latestOrderId ?? null,
    acknowledgementState:
      subscription.acknowledgementState ?? null,
  };
}

/**
 * Google Play 구독 상태를 Firestore에 저장한다.
 */
async function saveGoogleSubscriptionStatus(
  uid: string,
  subscription: ResolvedGoogleSubscription,
): Promise<void> {
  const subscriptionRef = db
    .collection("users")
    .doc(uid)
    .collection("subscription")
    .doc("status");

  await subscriptionRef.set(
    {
      storeActive: subscription.active,
      storeExpiresAt:
        subscription.expiryTimeMs !== null ?
          Timestamp.fromMillis(
            subscription.expiryTimeMs,
          ) :
          null,
      storeProductId: subscription.productId,
      storeTransactionId:
        subscription.latestOrderId,
      storePlatform: "android",
      storeEnvironment: "GooglePlay",
      storeStatus:
        subscription.subscriptionState,
      storeAcknowledgementState:
        subscription.acknowledgementState,
      storePurchaseToken:
        subscription.purchaseToken,
      storeRevokedAt: null,
      storeUpdatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );
}

/**
 * Google Play 구매 토큰과 Firebase UID의 소유 관계를 저장한다.
 * 이미 다른 UID에 연결된 토큰은 사용할 수 없다.
 */
async function claimGoogleSubscription(
  uid: string,
  subscription: ResolvedGoogleSubscription,
): Promise<void> {
  const mappingRef = db
    .collection("googlePlaySubscriptions")
    .doc(subscription.purchaseToken);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(mappingRef);
    const existingUid = snapshot.data()?.uid;

    if (
      typeof existingUid === "string" &&
      existingUid.length > 0 &&
      existingUid !== uid
    ) {
      throw new HttpsError(
        "permission-denied",
        "이 Google Play 구독은 다른 계정에 연결되어 있습니다.",
      );
    }

    transaction.set(
      mappingRef,
      {
        uid,
        productId: subscription.productId,
        purchaseToken: subscription.purchaseToken,
        latestOrderId: subscription.latestOrderId,
        subscriptionState:
          subscription.subscriptionState,
        expiryTime:
          subscription.expiryTimeMs !== null ?
            Timestamp.fromMillis(
              subscription.expiryTimeMs,
            ) :
            null,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt:
          snapshot.exists ?
            snapshot.data()?.createdAt ??
              FieldValue.serverTimestamp() :
            FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      },
    );
  });
}

/**
 * Production 또는 Sandbox 검증기로 알림 JWS를 검증한다.
 */
async function verifyNotification(
  signedPayload: string,
  config: AppleConfig,
): Promise<{
  environment: Environment;
  payload: Awaited<
    ReturnType<
      SignedDataVerifier["verifyAndDecodeNotification"]
    >
  >;
  verifier: SignedDataVerifier;
}> {
  let productionError: unknown;

  try {
    const verifier = createVerifier(
      config,
      Environment.PRODUCTION,
    );

    const payload =
      await verifier.verifyAndDecodeNotification(
        signedPayload,
      );

    return {
      environment: Environment.PRODUCTION,
      payload,
      verifier,
    };
  } catch (error) {
    productionError = error;
  }

  try {
    const verifier = createVerifier(
      config,
      Environment.SANDBOX,
    );

    const payload =
      await verifier.verifyAndDecodeNotification(
        signedPayload,
      );

    return {
      environment: Environment.SANDBOX,
      payload,
      verifier,
    };
  } catch (sandboxError) {
    console.error(
      "Apple 알림 서명 검증 실패",
      {
        productionError,
        sandboxError,
      },
    );

    throw new Error(
      "Apple 알림 서명을 검증하지 못했습니다.",
    );
  }
}

export const verifySubscriptionPurchase = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 60,
    secrets: [
      applePrivateKey,
      appleIssuerId,
      appleKeyId,
      appleBundleId,
      appleAppId,
    ],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const uid = request.auth.uid;
    const platform = request.data?.platform;
    const requestedProductId =
      request.data?.productId;
    const transactionId =
      request.data?.transactionId;

    if (platform !== "ios") {
      throw new HttpsError(
        "invalid-argument",
        "현재는 iOS 결제 검증만 지원합니다.",
      );
    }

    if (requestedProductId !== appleProductId) {
      throw new HttpsError(
        "invalid-argument",
        "허용되지 않은 구독 상품입니다.",
      );
    }

    if (
      typeof transactionId !== "string" ||
      transactionId.trim().length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Apple 거래 ID가 없습니다.",
      );
    }

    const config = loadAppleConfig();

    try {
      const subscription = await resolveSubscription(
        transactionId.trim(),
        config,
      );

      const claimResult =
        await claimAppleSubscription(
          uid,
          subscription,
        );

      await applyAppleSubscriptionStatus(
        uid,
        subscription,
        claimResult.previousUid,
      );

      return {
        success: true,
        active: subscription.active,
        productId: subscription.productId,
        transactionId:
          subscription.transactionId,
        originalTransactionId:
          subscription.originalTransactionId,
        expiresAt: subscription.expiresDateMs,
        environment:
          subscription.environment === Environment.PRODUCTION ?
            "Production" :
            "Sandbox",
        status: subscription.status,
        message: subscription.active ?
          "Apple 구독 검증 및 활성화 완료" :
          "구독이 만료되었거나 활성 상태가 아닙니다.",
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error instanceof APIException) {
        console.error(
          "App Store Server API 오류",
          {
            httpStatusCode: error.httpStatusCode,
            apiError: error.apiError,
            errorMessage: error.errorMessage,
          },
        );

        throw new HttpsError(
          "failed-precondition",
          "Apple에서 구독 상태를 확인하지 못했습니다.",
        );
      }

      console.error(
        "Apple 구독 검증 실패",
        error,
      );

      throw new HttpsError(
        "internal",
        "Apple 구독 검증 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 새 UID에 Apple 구독 상태를 저장하고,
 * 이전 익명 UID가 있다면 기존 프리미엄을 함께 해제한다.
 */
async function applyAppleSubscriptionStatus(
  uid: string,
  subscription: ResolvedSubscription,
  previousUid: string | null,
): Promise<void> {
  const batch = db.batch();

  const currentSubscriptionRef = db
    .collection("users")
    .doc(uid)
    .collection("subscription")
    .doc("status");

  batch.set(
    currentSubscriptionRef,
    {
      storeActive: subscription.active,
      storeExpiresAt:
        subscription.expiresDateMs !== null ?
          Timestamp.fromMillis(
            subscription.expiresDateMs,
          ) :
          null,
      storeProductId: subscription.productId,
      storeTransactionId:
        subscription.transactionId,
      storeOriginalTransactionId:
        subscription.originalTransactionId,
      storeEnvironment:
        subscription.environment === Environment.PRODUCTION ?
          "Production" :
          "Sandbox",
      storeStatus: subscription.status,
      storeRevokedAt:
        subscription.revocationDateMs !== null ?
          Timestamp.fromMillis(
            subscription.revocationDateMs,
          ) :
          null,
      storeUpdatedAt:
        FieldValue.serverTimestamp(),
    },
    {
      merge: true,
    },
  );

  if (
    previousUid !== null &&
    previousUid !== uid
  ) {
    const previousSubscriptionRef = db
      .collection("users")
      .doc(previousUid)
      .collection("subscription")
      .doc("status");

    batch.set(
      previousSubscriptionRef,
      {
        storeActive: false,
        storeExpiresAt: null,
        storeUpdatedAt:
          FieldValue.serverTimestamp(),
        storeTransferReason:
          "restored_to_new_uid",
        storeTransferredToUid:
          uid,
        storeOriginalTransactionId:
          subscription.originalTransactionId,
      },
      {
        merge: true,
      },
    );
  }

  await batch.commit();
}

export const verifyGooglePlaySubscription = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 60,
    serviceAccount: googlePlayServiceAccount,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const uid = request.auth.uid;
    const platform = request.data?.platform;
    const requestedProductId =
      request.data?.productId;
    const purchaseToken =
      request.data?.purchaseToken;

    if (platform !== "android") {
      throw new HttpsError(
        "invalid-argument",
        "Android 결제만 검증할 수 있습니다.",
      );
    }

    if (requestedProductId !== googleProductId) {
      throw new HttpsError(
        "invalid-argument",
        "허용되지 않은 Google Play 구독 상품입니다.",
      );
    }

    if (
      typeof purchaseToken !== "string" ||
      purchaseToken.trim().length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Google Play 구매 토큰이 없습니다.",
      );
    }

    try {
      const subscription =
        await resolveGoogleSubscription(
          purchaseToken.trim(),
        );

      await claimGoogleSubscription(
        uid,
        subscription,
      );

      await saveGoogleSubscriptionStatus(
        uid,
        subscription,
      );

      return {
        success: true,
        active: subscription.active,
        productId: subscription.productId,
        purchaseToken:
          subscription.purchaseToken,
        latestOrderId:
          subscription.latestOrderId,
        expiresAt:
          subscription.expiryTimeMs,
        status:
          subscription.subscriptionState,
        acknowledgementState:
          subscription.acknowledgementState,
        environment: "GooglePlay",
        message: subscription.active ?
          "Google Play 구독 검증 및 활성화 완료" :
          "Google Play 구독이 만료되었거나 활성 상태가 아닙니다.",
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      console.error(
        "Google Play 구독 검증 실패",
        error,
      );

      const status =
        (
          typeof error === "object" &&
          error !== null &&
          "response" in error
        ) ?
          (
            error as {
              response?: {
                status?: number;
                data?: unknown;
              };
            }
          ).response :
          undefined;

      console.error(
        "Google Play API 응답",
        status,
      );

      if (status?.status === 401) {
        throw new HttpsError(
          "permission-denied",
          "Google Play API 인증에 실패했습니다.",
        );
      }

      if (status?.status === 403) {
        throw new HttpsError(
          "permission-denied",
          "Google Play 구독 조회 권한이 없습니다.",
        );
      }

      if (status?.status === 404) {
        throw new HttpsError(
          "not-found",
          "Google Play 구매 정보를 찾지 못했습니다.",
        );
      }

      throw new HttpsError(
        "internal",
        "Google Play 구독 검증 중 오류가 발생했습니다.",
      );
    }
  },
);

export const appStoreNotifications = onRequest(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 60,
    secrets: [
      applePrivateKey,
      appleIssuerId,
      appleKeyId,
      appleBundleId,
      appleAppId,
    ],
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    const signedPayload =
      request.body?.signedPayload;

    if (
      typeof signedPayload !== "string" ||
      signedPayload.trim().length === 0
    ) {
      response.status(400).send("Missing signedPayload");
      return;
    }

    try {
      const config = loadAppleConfig();

      const {
        environment,
        payload,
        verifier,
      } = await verifyNotification(
        signedPayload,
        config,
      );

      const notificationUuid =
        payload.notificationUUID ?? null;

      if (notificationUuid) {
        const eventRef = db
          .collection("appleNotificationEvents")
          .doc(notificationUuid);

        const eventSnapshot = await eventRef.get();

        if (eventSnapshot.data()?.processed === true) {
          response.status(200).send("Already processed");
          return;
        }
      }

      // TEST 알림은 거래 정보가 없을 수 있다.
      if (payload.notificationType === "TEST") {
        if (notificationUuid) {
          await db
            .collection("appleNotificationEvents")
            .doc(notificationUuid)
            .set(
              {
                processed: true,
                notificationType:
                  payload.notificationType,
                subtype: payload.subtype ?? null,
                environment:
                  environment === Environment.PRODUCTION ?
                    "Production" :
                    "Sandbox",
                processedAt:
                  FieldValue.serverTimestamp(),
              },
              {
                merge: true,
              },
            );
        }

        response.status(200).send("TEST received");
        return;
      }

      const signedTransactionInfo =
        payload.data?.signedTransactionInfo;

      const signedRenewalInfo =
        payload.data?.signedRenewalInfo;

      let originalTransactionId: string | null = null;
      let notificationTransactionId: string | null = null;

      if (signedTransactionInfo) {
        const transaction =
          await verifier.verifyAndDecodeTransaction(
            signedTransactionInfo,
          );

        originalTransactionId =
          transaction.originalTransactionId ?? null;

        notificationTransactionId =
          transaction.transactionId ?? null;
      }

      if (
        !originalTransactionId &&
        signedRenewalInfo
      ) {
        const renewalInfo =
          await verifier.verifyAndDecodeRenewalInfo(
            signedRenewalInfo,
          );

        originalTransactionId =
          renewalInfo.originalTransactionId ?? null;
      }

      if (!originalTransactionId) {
        throw new Error(
          "알림에서 originalTransactionId를 찾지 못했습니다.",
        );
      }


      const mappingRef = db
        .collection("appleSubscriptions")
        .doc(originalTransactionId);

      const mappingSnapshot = await mappingRef.get();
      const uid = mappingSnapshot.data()?.uid;

      if (
        typeof uid !== "string" ||
        uid.length === 0
      ) {
        // 결제 직후 앱 검증보다 알림이 먼저 도착한 경우
        // Apple이 재시도하도록 500을 반환한다.
        response.status(500).send(
          "Subscription owner mapping not found",
        );
        return;
      }

      const lookupTransactionId =
        notificationTransactionId ?? originalTransactionId;

      const subscription = await resolveSubscription(
        lookupTransactionId,
        config,
      );

      await saveSubscriptionStatus(
        uid,
        subscription,
      );

      await mappingRef.set(
        {
          transactionId:
            subscription.transactionId,
          productId: subscription.productId,
          environment:
            subscription.environment === Environment.PRODUCTION ?
              "Production" :
              "Sandbox",
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );

      if (notificationUuid) {
        await db
          .collection("appleNotificationEvents")
          .doc(notificationUuid)
          .set(
            {
              processed: true,
              notificationType:
                payload.notificationType ?? null,
              subtype: payload.subtype ?? null,
              originalTransactionId,
              transactionId:
                subscription.transactionId,
              uid,
              active: subscription.active,
              environment:
                subscription.environment ===
                  Environment.PRODUCTION ?
                  "Production" :
                  "Sandbox",
              processedAt:
                FieldValue.serverTimestamp(),
            },
            {
              merge: true,
            },
          );
      }

      response.status(200).send("OK");
    } catch (error) {
      console.error(
        "App Store Server Notification 처리 실패",
        error,
      );

      // 2xx가 아니면 Apple이 정책에 따라 알림을 재시도한다.
      response.status(500).send(
        "Notification processing failed",
      );
    }
  },
);

/**
 * 현재 사용자의 최신 프로필 정보를
 * 모든 친구의 friends 문서에 동기화한다.
 *
 * @param {string} uid 사용자 UID
 * @return {Promise<void>}
 */
async function syncProfileToFriends(
  uid: string,
): Promise<void> {
  // =====================================================
  // 1. 현재 사용자의 최신 프로필 조회
  // =====================================================

  const userSnapshot = await db
    .collection("users")
    .doc(uid)
    .get();

  if (!userSnapshot.exists) {
    return;
  }

  const userData =
    userSnapshot.data();

  const nickname =
    typeof userData?.nickname === "string" ?
      userData.nickname :
      "";

  const bio =
    typeof userData?.bio === "string" ?
      userData.bio :
      "";

  const profileImageUrl =
    typeof userData?.profileImageUrl === "string" ?
      userData.profileImageUrl :
      "";

  // =====================================================
  // 2. 내 친구 목록 조회
  // =====================================================

  const friendsSnapshot = await db
    .collection("users")
    .doc(uid)
    .collection("friends")
    .get();

  if (friendsSnapshot.empty) {
    return;
  }

  // =====================================================
  // 3. 친구들의 friend 문서 갱신
  // =====================================================

  const friendUids: string[] = [];

  for (const friendDoc of friendsSnapshot.docs) {
    const friendData =
      friendDoc.data();

    const friendUid =
      typeof friendData.friendUid === "string" ?
        friendData.friendUid :
        friendDoc.id;

    if (friendUid) {
      friendUids.push(
        friendUid,
      );
    }
  }

  // batch write 제한보다 여유 있게
  // 400개씩 나누어 처리
  const chunkSize = 400;

  for (
    let i = 0;
    i < friendUids.length;
    i += chunkSize
  ) {
    const batch =
      db.batch();

    const chunk =
      friendUids.slice(
        i,
        i + chunkSize,
      );

    for (const friendUid of chunk) {
      const myProfileInFriendRef = db
        .collection("users")
        .doc(friendUid)
        .collection("friends")
        .doc(uid);

      batch.set(
        myProfileInFriendRef,
        {
          friendUid: uid,
          nickname,
          bio,
          profileImageUrl,
          updatedAt:
            FieldValue.serverTimestamp(),
        },
        {
          merge: true,
        },
      );
    }

    await batch.commit();
  }
}

export const changeNickname = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }

    const uid =
      request.auth.uid;

    const nickname =
      typeof request.data?.nickname === "string" ?
        request.data.nickname.trim() :
        "";

    if (
      !/^[가-힣a-zA-Z0-9]{2,12}$/.test(
        nickname,
      )
    ) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 2~12자, 한글/영문/숫자만 사용할 수 있습니다.",
      );
    }

    if (isReservedNickname(nickname)) {
      throw new HttpsError(
        "permission-denied",
        "사용할 수 없는 닉네임입니다.",
      );
    }

    const normalizedNickname =
      normalizeNickname(
        nickname,
      );

    const userRef =
      db
        .collection("users")
        .doc(uid);

    const newNicknameRef =
      db
        .collection("nicknames")
        .doc(normalizedNickname);

    try {
      await db.runTransaction(
        async (transaction) => {
          // =====================================================
          // 1. 사용자 문서 읽기
          // =====================================================

          const userSnapshot =
            await transaction.get(
              userRef,
            );

          if (!userSnapshot.exists) {
            throw new Error(
              USER_NOT_FOUND,
            );
          }

          const userData =
            userSnapshot.data();

          const oldNormalizedNickname =
            typeof userData?.nicknameNormalized ===
            "string" ?
              userData.nicknameNormalized :
              normalizeNickname(
                typeof userData?.nickname ===
                  "string" ?
                  userData.nickname :
                  "",
              );

          // =====================================================
          // 2. 필요한 문서를 모두 먼저 읽기
          // =====================================================

          const newNicknameSnapshot =
            await transaction.get(
              newNicknameRef,
            );

          const oldNicknameRef =
            oldNormalizedNickname.length > 0 ?
              db
                .collection("nicknames")
                .doc(
                  oldNormalizedNickname,
                ) :
              null;

          const oldNicknameSnapshot =
            oldNicknameRef !== null ?
              await transaction.get(
                oldNicknameRef,
              ) :
              null;

          // =====================================================
          // 3. 새 닉네임 중복 확인
          // =====================================================

          if (
            newNicknameSnapshot.exists
          ) {
            const existingUid =
              newNicknameSnapshot
                .data()
                ?.uid;

            if (existingUid !== uid) {
              throw new Error(
                NICKNAME_ALREADY_EXISTS,
              );
            }
          }

          // =====================================================
          // 4. 정규화 값이 같은 경우
          // 예: Junsoo → JUNSOO
          // =====================================================

          if (
            oldNormalizedNickname ===
            normalizedNickname
          ) {
            transaction.set(
              userRef,
              {
                nickname,
                nicknameNormalized:
                  normalizedNickname,
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              {
                merge: true,
              },
            );

            transaction.set(
              newNicknameRef,
              {
                uid,
                nickname,
                normalizedNickname,
                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              {
                merge: true,
              },
            );

            return;
          }

          // =====================================================
          // 5. 새 닉네임 선점
          // =====================================================

          transaction.set(
            newNicknameRef,
            {
              uid,
              nickname,
              normalizedNickname,
              createdAt:
                FieldValue
                  .serverTimestamp(),
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
            {
              merge: true,
            },
          );

          // =====================================================
          // 6. 이전 닉네임 문서 제거
          // =====================================================

          if (
            oldNicknameRef !== null &&
            oldNicknameSnapshot
              ?.exists === true &&
            oldNicknameSnapshot
              .data()
              ?.uid === uid
          ) {
            transaction.delete(
              oldNicknameRef,
            );
          }

          // =====================================================
          // 7. 사용자 문서 갱신
          // =====================================================

          transaction.set(
            userRef,
            {
              nickname,
              nicknameNormalized:
                normalizedNickname,
              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
            {
              merge: true,
            },
          );
        },
      );
    } catch (error) {
      const errorText =
        error instanceof Error ?
          error.message :
          String(error);

      console.error(
        "changeNickname transaction failed:",
        {
          error,
          errorText,
          uid,
          normalizedNickname,
        },
      );

      if (
        errorText.includes(
          NICKNAME_ALREADY_EXISTS,
        )
      ) {
        throw new HttpsError(
          "already-exists",
          "이미 사용 중인 닉네임입니다.",
        );
      }

      if (
        errorText.includes(
          USER_NOT_FOUND,
        )
      ) {
        throw new HttpsError(
          "not-found",
          "사용자 정보를 찾을 수 없습니다.",
        );
      }

      throw new HttpsError(
        "internal",
        "닉네임 변경 중 오류가 발생했습니다.",
      );
    }

    // =====================================================
    // 8. 친구들이 가지고 있는
    //    내 프로필 복사본 갱신
    // =====================================================

    try {
      await syncProfileToFriends(
        uid,
      );
    } catch (error) {
      // 닉네임 변경 자체는 이미 성공했으므로
      // 친구 동기화 실패 때문에 요청 전체를
      // 실패시키지는 않는다.
      console.error(
        "syncProfileToFriends failed " +
        "after nickname change:",
        {
          error,
          uid,
        },
      );
    }

    return {
      success: true,
      nickname,
      normalizedNickname,
    };
  },
);

/**
 * 현재 사용자의 최신 프로필 정보를
 * 친구들의 friends 문서에 동기화한다.
 *
 * nickname / bio / profileImageUrl
 */
export const syncFriendProfile = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }

    const uid =
      request.auth.uid;

    try {
      await syncProfileToFriends(
        uid,
      );

      return {
        success: true,
      };
    } catch (error) {
      console.error(
        "syncFriendProfile failed:",
        {
          error,
          uid,
        },
      );

      throw new HttpsError(
        "internal",
        "친구 프로필 정보를 동기화하지 못했습니다.",
      );
    }
  },
);

/**
 * 챌린지 그룹을 생성하거나
 * 현재 Attempt 그룹에 친구들을 추가 초대한다.
 *
 * 이미 다른 사람이 만든 동일 Attempt 그룹의 멤버라면
 * 새 그룹을 만들지 않고 기존 그룹을 재사용한다.
 */
export const createChallengeGroup = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const ownerUid =
      request.auth.uid;

    const challengeId =
      typeof request.data?.challengeId === "string" ?
        request.data.challengeId.trim() :
        "";

    const challengeTitle =
      typeof request.data?.challengeTitle === "string" ?
        request.data.challengeTitle.trim() :
        "";

    const ownerAttemptId =
      typeof request.data?.ownerAttemptId === "string" ?
        request.data.ownerAttemptId.trim() :
        "";

    const startDate =
      typeof request.data?.startDate === "string" ?
        request.data.startDate.trim() :
        "";

    const endDate =
      typeof request.data?.endDate === "string" ?
        request.data.endDate.trim() :
        null;

    const selectedDuration =
      typeof request.data?.selectedDuration === "number" ?
        request.data.selectedDuration :
        null;

    const stageIndex =
      typeof request.data?.stageIndex === "number" ?
        request.data.stageIndex :
        null;

    const participatingBooks =
      Array.isArray(
        request.data?.participatingBooks,
      ) ?
        request.data.participatingBooks :
        [];

    const rawInvitedFriendUids: unknown[] =
      Array.isArray(
        request.data?.invitedFriendUids,
      ) ?
        request.data.invitedFriendUids :
        [];

    const invitedFriendUids: string[] =
      Array.from(
        new Set<string>(
          rawInvitedFriendUids
            .filter(
              (
                uid: unknown,
              ): uid is string =>
                typeof uid === "string",
            )
            .map(
              (uid) =>
                uid.trim(),
            )
            .filter(
              (uid) =>
                uid.length > 0 &&
                uid !== ownerUid,
            ),
        ),
      );

    if (challengeId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 정보가 올바르지 않습니다.",
      );
    }

    if (challengeTitle.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 제목이 올바르지 않습니다.",
      );
    }

    if (ownerAttemptId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 도전 정보가 올바르지 않습니다.",
      );
    }

    if (startDate.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 시작일 정보가 올바르지 않습니다.",
      );
    }

    if (invitedFriendUids.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "초대할 친구를 선택해주세요.",
      );
    }

    try {
      const ownerRef =
        db
          .collection("users")
          .doc(ownerUid);

      const ownerSnapshot =
        await ownerRef.get();

      if (!ownerSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "사용자 정보를 찾을 수 없습니다.",
        );
      }

      const ownerData =
        ownerSnapshot.data() ?? {};

      const ownerNickname =
        typeof ownerData.nickname === "string" ?
          ownerData.nickname :
          "";

      // =====================================================
      // 실제 친구인지 검증
      // =====================================================

      const validFriendUids:
        string[] = [];

      for (
        const friendUid of
        invitedFriendUids
      ) {
        const friendSnapshot =
          await ownerRef
            .collection("friends")
            .doc(friendUid)
            .get();

        if (friendSnapshot.exists) {
          validFriendUids.push(
            friendUid,
          );
        }
      }

      if (validFriendUids.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "초대할 수 있는 친구가 없습니다.",
        );
      }

      // =====================================================
      // 내가 이미 속해 있는 현재 Attempt 그룹 검색
      //
      // 핵심:
      // ownerUid 기준이 아니라 memberUids 기준으로 찾는다.
      // 따라서 초대받아 참여한 사람도 같은 그룹을 재사용한다.
      // =====================================================

      const memberGroupSnapshot =
        await db
          .collection("challengeGroups")
          .where(
            "memberUids",
            "array-contains",
            ownerUid,
          )
          .get();

      let existingGroupDoc:
        FirebaseFirestore.QueryDocumentSnapshot | null =
        null;

      for (
        const doc of
        memberGroupSnapshot.docs
      ) {
        const data =
          doc.data();

        if (
          data.challengeId !==
          challengeId
        ) {
          continue;
        }

        const rawMemberAttemptIds =
          data.memberAttemptIds;

        if (
          rawMemberAttemptIds === null ||
          typeof rawMemberAttemptIds !== "object" ||
          Array.isArray(
            rawMemberAttemptIds,
          )
        ) {
          continue;
        }

        const memberAttemptIds =
          rawMemberAttemptIds as
            Record<string, unknown>;

        if (
          memberAttemptIds[ownerUid] ===
          ownerAttemptId
        ) {
          existingGroupDoc =
            doc;

          break;
        }
      }

      let groupRef:
        FirebaseFirestore.DocumentReference;

      let currentMemberUids:
        string[] = [];

      let currentInvitedUids:
        string[] = [];

      let currentMemberAttemptIds:
        Record<string, string> = {};

      if (existingGroupDoc === null) {
        groupRef =
          db
            .collection(
              "challengeGroups",
            )
            .doc();
      } else {
        groupRef =
          existingGroupDoc.ref;

        const existingData =
          existingGroupDoc.data();

        currentMemberUids =
          Array.isArray(
            existingData.memberUids,
          ) ?
            existingData.memberUids.filter(
              (
                uid: unknown,
              ): uid is string =>
                typeof uid === "string",
            ) :
            [];

        currentInvitedUids =
          Array.isArray(
            existingData.invitedUids,
          ) ?
            existingData.invitedUids.filter(
              (
                uid: unknown,
              ): uid is string =>
                typeof uid === "string",
            ) :
            [];

        const rawMemberAttemptIds =
          existingData.memberAttemptIds;

        currentMemberAttemptIds =
          rawMemberAttemptIds !== null &&
          typeof rawMemberAttemptIds === "object" &&
          !Array.isArray(
            rawMemberAttemptIds,
          ) ?
            Object.fromEntries(
              Object.entries(
                rawMemberAttemptIds,
              ).filter(
                (
                  entry,
                ): entry is [string, string] =>
                  typeof entry[1] === "string",
              ),
            ) :
            {};
      }

      // / =====================================================
      // 기존 멤버 중 실제로 포기한 사용자 정리
      //
      // challengeGroups에는 남아 있어도
      // 실제 Challenge가 더 이상 진행 중이 아니면
      // 그룹 멤버에서 제거하고 재초대 가능하게 한다.
      // =====================================================

      const staleMemberUids:
         string[] = [];

      for (
        const friendUid of
        validFriendUids
      ) {
        // 그룹 멤버가 아니라면 검사할 필요 없음
        if (
          !currentMemberUids.includes(
            friendUid,
          )
        ) {
          continue;
        }

        const memberAttemptId =
           currentMemberAttemptIds[
             friendUid
           ] ?? "";

        let isStillActive =
           false;

        if (
          memberAttemptId.length > 0
        ) {
          const friendChallengeSnapshot =
             await db
               .collection("users")
               .doc(friendUid)
               .collection("challenges")
               .doc(challengeId)
               .get();

          if (
            friendChallengeSnapshot.exists
          ) {
            const friendChallengeData =
               friendChallengeSnapshot.data() ?? {};

            const isJoined =
               friendChallengeData.isJoined ===
               true;

            const attempts =
               Array.isArray(
                 friendChallengeData.attempts,
               ) ?
                 friendChallengeData.attempts :
                 [];

            const targetAttempt =
               attempts.find(
                 (attempt: unknown) => {
                   if (
                     attempt === null ||
                     typeof attempt !== "object"
                   ) {
                     return false;
                   }

                   const attemptMap =
                     attempt as
                       Record<string, unknown>;

                   return (
                     typeof attemptMap.attemptId ===
                       "string" &&
                     attemptMap.attemptId ===
                       memberAttemptId
                   );
                 },
               );

            if (
              targetAttempt !== undefined &&
               targetAttempt !== null &&
               typeof targetAttempt ===
                 "object"
            ) {
              const attemptMap =
                 targetAttempt as
                   Record<string, unknown>;

              const completed =
                 attemptMap.completed ===
                 true;

              // 실제로 현재 참여 중이고
              // 해당 Attempt가 아직 끝나지 않았을 때만
              // 진짜 활성 멤버로 본다.
              isStillActive =
                 isJoined &&
                 !completed;
            }
          }
        }

        // challenge 문서가 삭제됐거나,
        // isJoined=false거나,
        // 해당 Attempt가 없거나,
        // Attempt가 끝났으면 stale
        if (!isStillActive) {
          staleMemberUids.push(
            friendUid,
          );
        }
      }

      // =====================================================
      // 포기한 멤버를 그룹에서 제거
      // =====================================================

      if (
        staleMemberUids.length > 0
      ) {
        const cleanedMemberAttemptIds = {
          ...currentMemberAttemptIds,
        };

        for (
          const staleUid of
          staleMemberUids
        ) {
          delete cleanedMemberAttemptIds[
            staleUid
          ];
        }

        await groupRef.update({
          memberUids:
             FieldValue.arrayRemove(
               ...staleMemberUids,
             ),

          memberAttemptIds:
             cleanedMemberAttemptIds,

          updatedAt:
             FieldValue.serverTimestamp(),
        });

        currentMemberUids =
           currentMemberUids.filter(
             (uid) =>
               !staleMemberUids.includes(
                 uid,
               ),
           );

        currentMemberAttemptIds =
           cleanedMemberAttemptIds;
      }

      // =====================================================
      // 실제 참여 중 / 이미 초대 중인 친구 제외
      // =====================================================

      const newInviteUids =
         validFriendUids.filter(
           (uid) =>
             !currentMemberUids.includes(
               uid,
             ) &&
             !currentInvitedUids.includes(
               uid,
             ),
         );

      if (newInviteUids.length === 0) {
        throw new HttpsError(
          "already-exists",
          "이미 함께 참여 중이거나 초대된 친구입니다.",
        );
      }

      const now =
        FieldValue.serverTimestamp();

      // =====================================================
      // 새 그룹
      // =====================================================

      if (existingGroupDoc === null) {
        await groupRef.set({
          challengeId,
          challengeTitle,

          ownerUid,
          ownerAttemptId,

          startDate,
          endDate,
          selectedDuration,
          stageIndex,

          participatingBooks,

          memberUids: [
            ownerUid,
          ],

          // ★ 핵심 수정
          memberAttemptIds: {
            [ownerUid]:
              ownerAttemptId,
          },

          invitedUids:
            newInviteUids,

          createdAt:
            now,

          updatedAt:
            now,
        });
      } else {
        // =================================================
        // 기존 그룹에 추가 초대
        // =================================================

        await groupRef.update({
          invitedUids:
            FieldValue.arrayUnion(
              ...newInviteUids,
            ),

          updatedAt:
            now,
        });
      }

      // =====================================================
      // 알림
      // =====================================================

      const batch =
        db.batch();

      for (
        const friendUid of
        newInviteUids
      ) {
        const notificationRef =
          db
            .collection("users")
            .doc(friendUid)
            .collection("notifications")
            .doc();

        batch.set(
          notificationRef,
          {
            type:
              "challenge_invite",

            title:
              "챌린지 초대",

            body:
              `${ownerNickname}님이 ` +
              `'${challengeTitle}' ` +
              "챌린지에 초대했습니다.",

            actorUid:
              ownerUid,

            actorNickname:
              ownerNickname,

            referenceId:
              groupRef.id,

            challengeId,

            ownerAttemptId,

            isRead:
              false,

            createdAt:
              FieldValue.serverTimestamp(),

            readAt:
              null,
          },
        );
      }

      await batch.commit();

      return {
        success: true,

        groupId:
          groupRef.id,

        invitedCount:
          newInviteUids.length,
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "createChallengeGroup failed:",
        {
          error,
          ownerUid,
          challengeId,
          ownerAttemptId,
        },
      );

      throw new HttpsError(
        "internal",
        "챌린지 초대를 보내는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 챌린지 초대 수락
 *
 * 실제 챌린지 참여가 성공한 뒤 호출한다.
 *
 * - invitedUids에서 제거
 * - memberUids에 추가
 * - 클라이언트가 실제 생성한 attemptId를
 *   memberAttemptIds에 정확히 저장
 */
export const acceptChallengeInvite = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const userUid =
      request.auth.uid;

    const groupId =
      typeof request.data?.groupId === "string" ?
        request.data.groupId.trim() :
        "";

    const memberAttemptId =
      typeof request.data?.memberAttemptId === "string" ?
        request.data.memberAttemptId.trim() :
        "";

    if (groupId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 그룹 정보가 올바르지 않습니다.",
      );
    }

    if (memberAttemptId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 도전 정보가 올바르지 않습니다.",
      );
    }

    try {
      const groupRef =
        db
          .collection("challengeGroups")
          .doc(groupId);

      const result =
        await db.runTransaction(
          async (transaction) => {
            // =================================================
            // 1. 그룹 조회
            // =================================================

            const groupSnapshot =
              await transaction.get(
                groupRef,
              );

            if (!groupSnapshot.exists) {
              throw new HttpsError(
                "not-found",
                "챌린지 초대를 찾을 수 없습니다.",
              );
            }

            const groupData =
              groupSnapshot.data() ?? {};

            const challengeId =
              typeof groupData.challengeId === "string" ?
                groupData.challengeId :
                "";

            const ownerUid =
              typeof groupData.ownerUid === "string" ?
                groupData.ownerUid :
                "";

            const challengeTitle =
              typeof groupData.challengeTitle === "string" ?
                groupData.challengeTitle :
                "";

            if (challengeId.length === 0) {
              throw new HttpsError(
                "failed-precondition",
                "챌린지 정보가 올바르지 않습니다.",
              );
            }

            // =================================================
            // 2. 현재 그룹 멤버 / 초대 목록
            // =================================================

            const invitedUids =
              Array.isArray(
                groupData.invitedUids,
              ) ?
                groupData.invitedUids.filter(
                  (
                    uid: unknown,
                  ): uid is string =>
                    typeof uid === "string",
                ) :
                [];

            const memberUids =
              Array.isArray(
                groupData.memberUids,
              ) ?
                groupData.memberUids.filter(
                  (
                    uid: unknown,
                  ): uid is string =>
                    typeof uid === "string",
                ) :
                [];

            const rawMemberAttemptIds =
              groupData.memberAttemptIds;

            const memberAttemptIds:
              Record<string, string> =
              rawMemberAttemptIds !== null &&
              typeof rawMemberAttemptIds === "object" &&
              !Array.isArray(
                rawMemberAttemptIds,
              ) ?
                Object.fromEntries(
                  Object.entries(
                    rawMemberAttemptIds,
                  ).filter(
                    (
                      entry,
                    ): entry is [string, string] =>
                      typeof entry[1] === "string",
                  ),
                ) :
                {};

            const alreadyMember =
              memberUids.includes(
                userUid,
              );

            // 이미 멤버가 아니라면 반드시
            // 유효한 초대 상태여야 한다.
            if (
              !alreadyMember &&
              !invitedUids.includes(
                userUid,
              )
            ) {
              throw new HttpsError(
                "permission-denied",
                "이 챌린지에 초대받지 않았습니다.",
              );
            }

            // =================================================
            // 3. 사용자의 실제 Challenge 조회
            // =================================================

            const userChallengeRef =
              db
                .collection("users")
                .doc(userUid)
                .collection("challenges")
                .doc(challengeId);

            const userChallengeSnapshot =
              await transaction.get(
                userChallengeRef,
              );

            if (
              !userChallengeSnapshot.exists
            ) {
              throw new HttpsError(
                "failed-precondition",
                "먼저 챌린지 참여를 완료해주세요.",
              );
            }

            const userChallengeData =
              userChallengeSnapshot.data() ?? {};

            if (
              userChallengeData.isJoined !==
              true
            ) {
              throw new HttpsError(
                "failed-precondition",
                "먼저 챌린지 참여를 완료해주세요.",
              );
            }

            const attempts =
              Array.isArray(
                userChallengeData.attempts,
              ) ?
                userChallengeData.attempts :
                [];

            // =================================================
            // 4. 클라이언트가 넘긴 정확한 attempt 찾기
            // =================================================

            const targetAttempt =
              attempts.find(
                (attempt: unknown) => {
                  if (
                    attempt === null ||
                    typeof attempt !==
                    "object"
                  ) {
                    return false;
                  }

                  const attemptMap =
                    attempt as
                      Record<string, unknown>;

                  return (
                    typeof attemptMap.attemptId ===
                      "string" &&
                    attemptMap.attemptId ===
                      memberAttemptId
                  );
                },
              );

            if (
              targetAttempt === undefined ||
              targetAttempt === null ||
              typeof targetAttempt !==
              "object"
            ) {
              throw new HttpsError(
                "failed-precondition",
                "참여한 챌린지 도전 정보를 찾을 수 없습니다.",
              );
            }

            const attemptMap =
              targetAttempt as
                Record<string, unknown>;

            // =================================================
            // 5. 그룹 설정과 Attempt 설정 일치 확인
            // =================================================

            const groupStartDate =
              typeof groupData.startDate === "string" ?
                groupData.startDate :
                "";

            const attemptStartDate =
              typeof attemptMap.startDate === "string" ?
                attemptMap.startDate :
                "";

            const groupDuration =
              typeof groupData.selectedDuration === "number" ?
                groupData.selectedDuration :
                null;

            const attemptDuration =
              typeof attemptMap.selectedDuration === "number" ?
                attemptMap.selectedDuration :
                null;

            const groupStageIndex =
              typeof groupData.stageIndex === "number" ?
                groupData.stageIndex :
                null;

            const attemptStageIndex =
              typeof attemptMap.stageIndex === "number" ?
                attemptMap.stageIndex :
                null;

            if (
              groupStartDate.length > 0 &&
              attemptStartDate !==
                groupStartDate
            ) {
              throw new HttpsError(
                "failed-precondition",
                "챌린지 시작일이 초대 설정과 일치하지 않습니다.",
              );
            }

            if (
              groupDuration !==
                attemptDuration
            ) {
              throw new HttpsError(
                "failed-precondition",
                "챌린지 기간 설정이 초대와 일치하지 않습니다.",
              );
            }

            if (
              groupStageIndex !==
                attemptStageIndex
            ) {
              throw new HttpsError(
                "failed-precondition",
                "챌린지 단계가 초대와 일치하지 않습니다.",
              );
            }

            // =================================================
            // 6. 그룹 멤버 / attemptId 저장
            //
            // alreadyMember여도 memberAttemptIds가 빠졌거나
            // 잘못된 경우 다시 덮어쓸 수 있다.
            // =================================================

            const updatedMemberAttemptIds = {
              ...memberAttemptIds,

              [userUid]:
                memberAttemptId,
            };

            transaction.update(
              groupRef,
              {
                invitedUids:
                  FieldValue.arrayRemove(
                    userUid,
                  ),

                memberUids:
                  FieldValue.arrayUnion(
                    userUid,
                  ),

                memberAttemptIds:
                  updatedMemberAttemptIds,

                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
            );

            return {
              alreadyMember,
              ownerUid,
              challengeTitle,
              memberAttemptId,
            };
          },
        );

      return {
        success: true,

        groupId,

        alreadyMember:
          result.alreadyMember,

        memberAttemptId:
          result.memberAttemptId,
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "acceptChallengeInvite failed:",
        {
          error,
          userUid,
          groupId,
          memberAttemptId,
        },
      );

      throw new HttpsError(
        "internal",
        "챌린지 초대를 수락하는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 챌린지 초대 거절
 */
export const rejectChallengeInvite = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const userUid =
      request.auth.uid;

    const groupId =
      typeof request.data?.groupId === "string" ?
        request.data.groupId.trim() :
        "";

    if (groupId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 그룹 정보가 올바르지 않습니다.",
      );
    }

    try {
      const groupRef =
        db
          .collection("challengeGroups")
          .doc(groupId);

      await db.runTransaction(
        async (transaction) => {
          const groupSnapshot =
            await transaction.get(
              groupRef,
            );

          if (!groupSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "챌린지 초대를 찾을 수 없습니다.",
            );
          }

          const groupData =
            groupSnapshot.data() ?? {};

          const invitedUids =
            Array.isArray(
              groupData.invitedUids,
            ) ?
              groupData.invitedUids.filter(
                (
                  uid: unknown,
                ): uid is string =>
                  typeof uid === "string",
              ) :
              [];

          const memberUids =
            Array.isArray(
              groupData.memberUids,
            ) ?
              groupData.memberUids.filter(
                (
                  uid: unknown,
                ): uid is string =>
                  typeof uid === "string",
              ) :
              [];

          if (
            memberUids.includes(
              userUid,
            )
          ) {
            throw new HttpsError(
              "failed-precondition",
              "이미 참여 중인 챌린지입니다.",
            );
          }

          // 이미 초대 목록에서 빠졌다면
          // 다시 거절할 필요 없음
          if (
            !invitedUids.includes(
              userUid,
            )
          ) {
            return;
          }

          transaction.update(
            groupRef,
            {
              invitedUids:
                FieldValue.arrayRemove(
                  userUid,
                ),

              updatedAt:
                FieldValue
                  .serverTimestamp(),
            },
          );
        },
      );

      return {
        success: true,
        groupId,
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "rejectChallengeInvite failed:",
        {
          error,
          userUid,
          groupId,
        },
      );

      throw new HttpsError(
        "internal",
        "챌린지 초대를 거절하는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 챌린지 초대 그룹 정보를 가져온다.
 *
 * 초대받은 사용자 또는 이미 참여 중인 멤버만 조회 가능.
 *
 * 커스텀 챌린지 대응:
 * 초대한 사람(owner)의 실제 Challenge 데이터도 함께 반환한다.
 */
export const getChallengeGroupInvitation = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const uid =
      request.auth.uid;

    const groupId =
      typeof request.data?.groupId === "string" ?
        request.data.groupId.trim() :
        "";

    if (groupId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 그룹 정보가 올바르지 않습니다.",
      );
    }

    try {
      // =====================================================
      // 1. 그룹 조회
      // =====================================================

      const groupRef =
        db
          .collection("challengeGroups")
          .doc(groupId);

      const groupSnapshot =
        await groupRef.get();

      if (!groupSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "챌린지 초대를 찾을 수 없습니다.",
        );
      }

      const data =
        groupSnapshot.data() ?? {};

      // =====================================================
      // 2. 기본 그룹 정보
      // =====================================================

      const ownerUid =
        typeof data.ownerUid === "string" ?
          data.ownerUid :
          "";

      const challengeId =
        typeof data.challengeId === "string" ?
          data.challengeId :
          "";

      const memberUids =
        Array.isArray(data.memberUids) ?
          data.memberUids.filter(
            (
              value: unknown,
            ): value is string =>
              typeof value === "string",
          ) :
          [];

      const invitedUids =
        Array.isArray(data.invitedUids) ?
          data.invitedUids.filter(
            (
              value: unknown,
            ): value is string =>
              typeof value === "string",
          ) :
          [];

      // =====================================================
      // 3. 접근 권한 확인
      // =====================================================

      const canAccess =
        uid === ownerUid ||
        memberUids.includes(uid) ||
        invitedUids.includes(uid);

      if (!canAccess) {
        throw new HttpsError(
          "permission-denied",
          "이 챌린지 그룹을 확인할 권한이 없습니다.",
        );
      }

      // =====================================================
      // 4. 초대한 사람의 Challenge 원본 조회
      //
      // 시스템 챌린지뿐 아니라
      // 커스텀 챌린지도 초대받은 사람이
      // 상세 화면을 열 수 있도록 원본 정의를 같이 내려준다.
      // =====================================================

      let challengeData:
        Record<string, unknown> | null =
        null;

      if (
        ownerUid.length > 0 &&
        challengeId.length > 0
      ) {
        const ownerChallengeRef =
          db
            .collection("users")
            .doc(ownerUid)
            .collection("challenges")
            .doc(challengeId);

        const ownerChallengeSnapshot =
          await ownerChallengeRef.get();

        if (ownerChallengeSnapshot.exists) {
          challengeData = {
            ...ownerChallengeSnapshot.data(),

            // id가 문서 내부에 없더라도 보장
            id:
              challengeId,
          };
        }
      }

      // =====================================================
      // 5. 결과 반환
      // =====================================================

      return {
        success: true,

        groupId,

        challengeId,

        challengeTitle:
          typeof data.challengeTitle === "string" ?
            data.challengeTitle :
            "",

        ownerUid,

        ownerAttemptId:
          typeof data.ownerAttemptId === "string" ?
            data.ownerAttemptId :
            "",

        startDate:
          typeof data.startDate === "string" ?
            data.startDate :
            "",

        endDate:
          typeof data.endDate === "string" ?
            data.endDate :
            null,

        selectedDuration:
          typeof data.selectedDuration === "number" ?
            data.selectedDuration :
            null,

        stageIndex:
          typeof data.stageIndex === "number" ?
            data.stageIndex :
            null,

        participatingBooks:
          Array.isArray(
            data.participatingBooks,
          ) ?
            data.participatingBooks :
            [],

        memberUids,
        invitedUids,

        // ★ 커스텀 챌린지 대응 핵심
        challenge:
          challengeData,

        isInvited:
          invitedUids.includes(uid),

        isMember:
          memberUids.includes(uid),
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "getChallengeGroupInvitation failed:",
        {
          error,
          uid,
          groupId,
        },
      );

      throw new HttpsError(
        "internal",
        "챌린지 초대 정보를 불러오는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 함께 도전 중인 챌린지 그룹 멤버 정보를 가져온다.
 *
 * 그룹에 실제로 참여 중인 멤버만 조회한다.
 * 현재 요청자는 제외하고 친구들만 반환한다.
 *
 * 각 멤버마다:
 * - 프로필
 * - 그룹에 연결된 정확한 attempt
 * - 해당 challenge 데이터
 * - 진행률 계산에 필요한 savedBooks
 *
 * 를 반환한다.
 */
export const getChallengeGroupMembers = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const requesterUid =
      request.auth.uid;

    const groupId =
      typeof request.data?.groupId === "string" ?
        request.data.groupId.trim() :
        "";

    const rawTargetBookIds:
          unknown[] =
          Array.isArray(
            request.data?.targetBookIds,
          ) ?
            request.data.targetBookIds :
            [];

    const targetBookIds:
          string[] =
          Array.from(
            new Set(
              rawTargetBookIds
                .filter(
                  (
                    value: unknown,
                  ): value is string =>
                    typeof value === "string",
                )
                .map(
                  (value) =>
                    value.trim(),
                )
                .filter(
                  (value) =>
                    value.length > 0,
                ),
            ),
          );

    if (groupId.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 그룹 정보가 올바르지 않습니다.",
      );
    }

    try {
      // =====================================================
      // 1. 그룹 조회
      // =====================================================

      const groupRef =
        db
          .collection("challengeGroups")
          .doc(groupId);

      const groupSnapshot =
        await groupRef.get();

      if (!groupSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "챌린지 그룹을 찾을 수 없습니다.",
        );
      }

      const groupData =
        groupSnapshot.data() ?? {};

      const challengeId =
        typeof groupData.challengeId === "string" ?
          groupData.challengeId :
          "";

      if (challengeId.length === 0) {
        throw new HttpsError(
          "failed-precondition",
          "챌린지 정보가 올바르지 않습니다.",
        );
      }

      // =====================================================
      // 2. 실제 참여 중인 멤버
      // =====================================================

      const memberUids =
        Array.isArray(
          groupData.memberUids,
        ) ?
          groupData.memberUids.filter(
            (
              uid: unknown,
            ): uid is string =>
              typeof uid === "string" &&
              uid.length > 0,
          ) :
          [];

      if (
        !memberUids.includes(
          requesterUid,
        )
      ) {
        throw new HttpsError(
          "permission-denied",
          "이 챌린지 그룹의 멤버가 아닙니다.",
        );
      }

      // =====================================================
      // 3. uid → attemptId 맵
      // =====================================================

      const rawMemberAttemptIds =
        groupData.memberAttemptIds;

      const memberAttemptIds:
        Record<string, string> =
        rawMemberAttemptIds !== null &&
        typeof rawMemberAttemptIds === "object" &&
        !Array.isArray(rawMemberAttemptIds) ?
          Object.fromEntries(
            Object.entries(
              rawMemberAttemptIds,
            ).filter(
              (
                entry,
              ): entry is [string, string] =>
                typeof entry[1] === "string" &&
                entry[1].length > 0,
            ),
          ) :
          {};

      // =====================================================
      // 4. 현재 사용자는 카드에서 제외
      // =====================================================

      const targetMemberUids =
        memberUids.filter(
          (uid) =>
            uid !== requesterUid,
        );

      if (
        targetMemberUids.length === 0
      ) {
        return {
          success: true,
          groupId,
          challengeId,
          members: [],
        };
      }

      // =====================================================
      // 5. 각 멤버 정보 조회
      // =====================================================

      const members =
        await Promise.all(
          targetMemberUids.map(
            async (memberUid) => {
              const attemptId =
                memberAttemptIds[
                  memberUid
                ] ?? "";

              // attemptId가 없다면
              // 그룹 진행률을 정확히 계산할 수 없음
              if (
                attemptId.length === 0
              ) {
                console.warn(
                  "Challenge group member attempt missing:",
                  {
                    groupId,
                    memberUid,
                  },
                );

                return null;
              }

              // =============================================
              // 프로필
              // =============================================

              const userRef =
                db
                  .collection("users")
                  .doc(memberUid);

              // =============================================
              // user / challenge / savedBooks 동시 조회
              // =============================================

              const savedBooksPromise:
                Promise<
                  FirebaseFirestore.DocumentSnapshot[]
                > =
                targetBookIds.length > 0 ?
                  db.getAll(
                    ...targetBookIds.map(
                      (bookId) =>
                        userRef
                          .collection("savedBooks")
                          .doc(bookId),
                    ),
                  ) :
                  userRef
                    .collection("savedBooks")
                    .get()
                    .then(
                      (snapshot) =>
                        snapshot.docs,
                    );

              const [
                userSnapshot,
                challengeSnapshot,
                savedBookSnapshots,
              ] = await Promise.all([
                userRef.get(),

                userRef
                  .collection("challenges")
                  .doc(challengeId)
                  .get(),

                savedBooksPromise,
              ]);

              // =============================================
              // User
              // =============================================

              if (!userSnapshot.exists) {
                return null;
              }

              const userData =
                userSnapshot.data() ?? {};

              // =============================================
              // Challenge
              // =============================================

              if (!challengeSnapshot.exists) {
                console.warn(
                  "Challenge group member challenge missing:",
                  {
                    groupId,
                    memberUid,
                    challengeId,
                  },
                );

                return null;
              }

              const challengeData =
                challengeSnapshot.data() ?? {};

              const attempts =
                Array.isArray(
                  challengeData.attempts,
                ) ?
                  challengeData.attempts :
                  [];

              // =============================================
              // 그룹에 연결된 정확한 Attempt 찾기
              // =============================================

              const targetAttempt =
                attempts.find(
                  (attempt: unknown) => {
                    if (
                      attempt === null ||
                      typeof attempt !== "object"
                    ) {
                      return false;
                    }

                    const attemptMap =
                      attempt as
                        Record<string, unknown>;

                    return (
                      typeof attemptMap.attemptId ===
                        "string" &&
                      attemptMap.attemptId ===
                        attemptId
                    );
                  },
                );

              if (
                targetAttempt === undefined ||
                targetAttempt === null ||
                typeof targetAttempt !== "object"
              ) {
                console.warn(
                  "Challenge group attempt not found:",
                  {
                    groupId,
                    memberUid,
                    challengeId,
                    attemptId,
                  },
                );

                return null;
              }

              // =============================================
              // savedBooks
              //
              // pageAuto / libraryAuto 진행률 계산용
              // =============================================

              const savedBooks =
                savedBookSnapshots
                  .filter(
                    (bookDoc) =>
                      bookDoc.exists,
                  )
                  .map(
                    (bookDoc) => {
                      const data =
                        bookDoc.data() ?? {};

                      const storedId =
                        typeof data.id === "string" &&
                        data.id.length > 0 ?
                          data.id :
                          bookDoc.id;

                      return {
                        ...data,
                        id: storedId,
                      };
                    },
                  );

              // =============================================
              // ChallengeProgressUtils는
              // attempts.last 기준 로직이 많으므로
              //
              // 이번 그룹의 attempt 하나만 넣어서 반환한다.
              // =============================================

              const challengeForGroup = {
                ...challengeData,

                attempts: [
                  targetAttempt,
                ],
              };

              return {
                uid:
                  memberUid,

                nickname:
                  typeof userData.nickname === "string" ?
                    userData.nickname :
                    "",

                profileImageUrl:
                  typeof userData.profileImageUrl ===
                    "string" ?
                    userData.profileImageUrl :
                    "",

                attemptId,

                challenge:
                  challengeForGroup,

                attempt:
                  targetAttempt,

                savedBooks,
              };
            },
          ),
        );

      // =====================================================
      // 6. 조회 실패 멤버 제거
      // =====================================================

      const filteredMembers =
        members.filter(
          (member) =>
            member !== null,
        );

      return {
        success: true,

        groupId,

        challengeId,

        members:
          filteredMembers,
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "getChallengeGroupMembers failed:",
        {
          error,
          requesterUid,
          groupId,
        },
      );

      throw new HttpsError(
        "internal",
        "함께 도전 중인 친구 정보를 불러오는 중 오류가 발생했습니다.",
      );
    }
  },
);

/**
 * 현재 Challenge Attempt가 속한 함께 도전 그룹 조회
 */
export const getChallengeGroupForAttempt = onCall(
  {
    region: "asia-northeast3",
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요한 기능입니다.",
      );
    }

    const uid =
      request.auth.uid;

    const challengeId =
      typeof request.data?.challengeId === "string" ?
        request.data.challengeId.trim() :
        "";

    const attemptId =
      typeof request.data?.attemptId === "string" ?
        request.data.attemptId.trim() :
        "";

    if (
      challengeId.length === 0 ||
      attemptId.length === 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "챌린지 도전 정보가 올바르지 않습니다.",
      );
    }

    try {
      const snapshot =
        await db
          .collection("challengeGroups")
          .where(
            "memberUids",
            "array-contains",
            uid,
          )
          .where(
            "challengeId",
            "==",
            challengeId,
          )
          .get();

      for (const doc of snapshot.docs) {
        const data =
          doc.data();


        const rawMemberAttemptIds =
          data.memberAttemptIds;

        if (
          rawMemberAttemptIds === null ||
          typeof rawMemberAttemptIds !== "object" ||
          Array.isArray(rawMemberAttemptIds)
        ) {
          continue;
        }

        const memberAttemptIds =
          rawMemberAttemptIds as
            Record<string, unknown>;

        if (
          memberAttemptIds[uid] ===
          attemptId
        ) {
          return {
            success: true,
            groupId: doc.id,
          };
        }
      }

      // 그룹이 없는 건 오류가 아님.
      // 아직 아무 친구와 함께하지 않는 일반 챌린지일 수 있음.
      return {
        success: true,
        groupId: null,
      };
    } catch (error) {
      if (
        error instanceof HttpsError
      ) {
        throw error;
      }

      console.error(
        "getChallengeGroupForAttempt failed:",
        {
          error,
          uid,
          challengeId,
          attemptId,
        },
      );

      throw new HttpsError(
        "internal",
        "함께 도전 그룹을 확인하는 중 오류가 발생했습니다.",
      );
    }
  },
);
