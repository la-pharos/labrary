import {onRequest, onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import {createHash} from "crypto";
import sharp from "sharp";

const YES24_API_KEY = defineSecret("YES24_API_KEY");

const YES24_PLACEHOLDER_SPINE_HASH =
  "7b8d5fea77ae3a56de1b7a1b52cc215dd8fc376af996704bf82da52431b9498f";

export const health = onRequest((req, res) => {
  logger.info("health check", {method: req.method});
  res.status(200).send("OK");
});

export const getYes24BookByIsbn = onCall(
  {
    region: "asia-northeast3",
    secrets: [YES24_API_KEY],
  },
  async (request) => {
    const isbn = String(request.data?.isbn ?? "")
      .replace(/[^0-9Xx]/g, "")
      .trim();

    if (!isbn) {
      throw new HttpsError(
        "invalid-argument",
        "ISBN이 필요합니다."
      );
    }

    try {
      const url = new URL(
        "https://apis.yes24.com/v1/goods/itemDetail"
      );

      url.searchParams.set("searchType", "ISBN13");
      url.searchParams.set("query", isbn);
      url.searchParams.set("detail", "Y");

      const response = await fetch(url, {
        method: "GET",
        headers: {
          "X-Api-Key": YES24_API_KEY.value(),
          "Accept": "application/json",
        },
      });

      // ✅ YES24 API 오류가 나도 앱까지 INTERNAL 예외를 던지지 않음
      if (!response.ok) {
        const body = await response.text();

        logger.warn("YES24 API 조회 실패", {
          isbn,
          status: response.status,
          body,
        });

        return {
          found: false,
          reason: "api_error",
        };
      }

      let json: any;

      try {
        json = await response.json();
      } catch (error) {
        logger.warn("YES24 JSON 파싱 실패", {
          isbn,
          error,
        });

        return {
          found: false,
          reason: "invalid_response",
        };
      }

      const items = json?.data?.items;

      if (!Array.isArray(items) || items.length === 0) {
        return {
          found: false,
          reason: "not_found",
        };
      }

      const item = items[0];
      const itemId = item?.itemId?.toString();

      if (!itemId) {
        return {
          found: false,
          reason: "missing_item_id",
        };
      }

      const candidateSpineUrl =
        `https://image.yes24.com/goods/${itemId}/SIDE/XL`;

      /*
       * 실제로 책등 URL이 응답 가능한지 확인.
       *
       * 404 / 서버 오류 등이면 spineUrl을 null로 내려서
       * Flutter에서 Labrary fallback 책등을 사용한다.
       *
       * 주의:
       * YES24가 "이미지 준비중" 이미지를 HTTP 200으로 보내는 경우는
       * 이 검사만으로는 아직 구분할 수 없다.
       */
      let spineUrl: string | null = null;
      let spineHash: string | null = null;

      try {
        const spineResponse = await fetch(
          candidateSpineUrl,
          {
            method: "GET",
          }
        );

        const contentType =
          spineResponse.headers.get("content-type") ?? "";

        if (
          spineResponse.ok &&
          contentType.startsWith("image/")
        ) {
          const arrayBuffer =
            await spineResponse.arrayBuffer();

          const buffer =
            Buffer.from(arrayBuffer);

          const normalizedPixels = await sharp(buffer)
            .resize(32, 32, {
              fit: "fill",
            })
            .grayscale()
            .raw()
            .toBuffer();

          spineHash = createHash("sha256")
            .update(normalizedPixels)
            .digest("hex");

          logger.info("YES24 책등 이미지 정보", {
            isbn,
            itemId,
            spineHash,
            byteLength: buffer.length,
            spineUrl: candidateSpineUrl,
          });

          if (spineHash === YES24_PLACEHOLDER_SPINE_HASH) {
            logger.info("YES24 책등 이미지 미제공", {
              isbn,
              itemId,
            });

            spineUrl = null;
          } else {
            spineUrl = candidateSpineUrl;
          }
        }
      } catch (error) {
        logger.warn("YES24 책등 확인 실패", {
          isbn,
          itemId,
          error,
        });
      }


      // YES24 페이지수 추출
      const rawPages = item.pages;
      const parsedPages = Number(rawPages);

      const pageCount =
      rawPages !== null &&
      rawPages !== undefined &&
      rawPages !== "" &&
      Number.isInteger(parsedPages) &&
      parsedPages > 0 ?
        parsedPages :
        0;

      return {
        found: true,
        itemId,
        title: item.title ?? "",
        author: item.author ?? "",
        publisher: item.publisher ?? "",
        isbn13: item.isbn13 ?? isbn,

        // 도서 페이지수
        pageCount,

        // YES24 앞표지 이미지
        coverUrl: item.cover ?? null,

        // YES24 도서 소개
        description:
          item.contentDetail?.bookIntroduction ??
          item.contentDetail?.bookSummary ??
          "",

        // 기존 책등 이미지
        spineUrl,

        // 임시 디버깅용
        spineHash,
      };
    } catch (error) {
      /*
       * 예상하지 못한 오류도 앱까지 INTERNAL로 넘기지 않는다.
       * 해당 책만 fallback 처리.
       */
      logger.error(
        "getYes24BookByIsbn 예상치 못한 오류",
        {
          isbn,
          error,
        }
      );

      return {
        found: false,
        reason: "unexpected_error",
      };
    }
  }
);

export const searchYes24Books = onCall(
  {
    region: "asia-northeast3",
    secrets: [YES24_API_KEY],
    timeoutSeconds: 30,
  },
  async (request) => {
    const query = String(request.data?.query ?? "").trim();
    const rawLimit = Number(request.data?.maxResults ?? 15);
    const limit = Number.isFinite(rawLimit) ?
      Math.min(30, Math.max(1, Math.floor(rawLimit))) :
      15;

    if (!query || query.length > 100) {
      throw new HttpsError(
        "invalid-argument",
        "검색어는 1~100자로 입력해주세요."
      );
    }

    try {
      const url = new URL(
        "https://apis.yes24.com/v1/goods/itemList"
      );

      url.searchParams.set("query", query);
      url.searchParams.set("page", "1");
      url.searchParams.set("pageSize", String(limit));
      url.searchParams.set("detail", "Y");

      const response = await fetch(url, {
        method: "GET",
        headers: {
          "X-Api-Key": YES24_API_KEY.value(),
          "Accept": "application/json",
        },
        signal: AbortSignal.timeout(12000),
      });

      if (!response.ok) {
        logger.warn("YES24 검색 실패", {
          status: response.status,
        });
        return {success: false, books: []};
      }

      const json = await response.json();

      if (json?.success !== true) {
        return {success: false, books: []};
      }

      const items = json?.data?.items;

      if (!Array.isArray(items)) {
        return {success: false, books: []};
      }

      const books = items
        .filter((item: any) =>
          item &&
          item.adultYn !== "Y" &&
          typeof item.title === "string" &&
          item.title.trim().length > 0
        )
        .map((item: any) => {
          const pages = Number(item.pages);

          return {
            yes24ItemId: String(item.itemId ?? ""),
            title: String(item.title ?? ""),
            author: String(item.author ?? ""),
            publisher: String(item.publisher ?? ""),
            isbn13: String(item.isbn13 ?? ""),
            description: String(
              item.contentDetail?.bookIntroduction ??
              item.contentDetail?.bookSummary ??
              ""
            ),
            coverUrl: String(item.cover ?? ""),
            pageCount:
              item.pages != null &&
              Number.isInteger(pages) &&
              pages > 0 ?
                pages :
                0,
          };
        });

      return {
        success: true,
        books,
      };
    } catch (error) {
      logger.error("YES24 검색 예외", {error});
      return {success: false, books: []};
    }
  }
);


/**
 * YES24 종합 베스트셀러 TOP 10
 *
 * 도서 검색 화면의 베스트셀러 영역에서 사용
 */
export const getYes24Bestsellers = onCall(
  {
    region: "asia-northeast3",
    secrets: [YES24_API_KEY],
    timeoutSeconds: 30,
  },
  async () => {
    try {
      const url = new URL(
        "https://apis.yes24.com/v1/category/bestseller"
      );

      url.searchParams.set("categoryId", "001");
      url.searchParams.set("page", "1");
      url.searchParams.set("pageSize", "10");
      url.searchParams.set("detail", "Y");

      const response = await fetch(url, {
        method: "GET",
        headers: {
          "X-Api-Key": YES24_API_KEY.value(),
          "Accept": "application/json",
        },
        signal: AbortSignal.timeout(12000),
      });

      if (!response.ok) {
        logger.warn("YES24 베스트셀러 조회 실패", {
          status: response.status,
        });

        return {
          success: false,
          books: [],
        };
      }

      const json = await response.json();

      if (json?.success !== true) {
        logger.warn("YES24 베스트셀러 응답 실패");

        return {
          success: false,
          books: [],
        };
      }

      const items = json?.data?.items;

      if (!Array.isArray(items)) {
        logger.warn("YES24 베스트셀러 목록 없음");

        return {
          success: false,
          books: [],
        };
      }

      const books = items
        .filter((item: any) =>
          item &&
          item.adultYn !== "Y" &&
          typeof item.title === "string" &&
          item.title.trim().length > 0
        )
        .map((item: any) => {
          const pages = Number(item.pages);
          const rank = Number(item.sortOrder);

          return {
            rank: Number.isInteger(rank) &&
              rank > 0 ? rank : null,
            yes24ItemId: String(item.itemId ?? ""),
            title: String(item.title ?? ""),
            author: String(item.author ?? ""),
            publisher: String(item.publisher ?? ""),
            isbn13: String(item.isbn13 ?? ""),
            description: String(
              item.contentDetail?.bookIntroduction ??
              item.contentDetail?.bookSummary ??
              ""
            ),
            coverUrl: String(item.cover ?? ""),
            pageCount:
              item.pages != null &&
              Number.isInteger(pages) &&
              pages > 0 ?
                pages :
                0,
          };
        });

      logger.info("YES24 베스트셀러 조회 성공", {
        count: books.length,
      });

      return {
        success: true,
        books,
      };
    } catch (error) {
      logger.error("YES24 베스트셀러 조회 예외", {
        error,
      });

      return {
        success: false,
        books: [],
      };
    }
  }
);
