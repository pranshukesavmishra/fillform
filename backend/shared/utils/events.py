"""Kafka event producer/consumer for inter-service communication."""

import json
import logging
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from enum import Enum
from typing import Callable, Awaitable
import uuid

from aiokafka import AIOKafkaProducer, AIOKafkaConsumer
from backend.shared.config.settings import settings

logger = logging.getLogger(__name__)


class EventTopic(str, Enum):
    # Student lifecycle
    STUDENT_REGISTERED = "student.registered"
    STUDENT_PROFILE_UPDATED = "student.profile.updated"
    STUDENT_DOCUMENT_UPLOADED = "student.document.uploaded"

    # Opportunity lifecycle
    OPPORTUNITY_DISCOVERED = "opportunity.discovered"
    OPPORTUNITY_DEADLINE_APPROACHING = "opportunity.deadline.approaching"
    OPPORTUNITY_CLOSED = "opportunity.closed"

    # Application lifecycle
    APPLICATION_STARTED = "application.started"
    APPLICATION_SUBMITTED = "application.submitted"
    APPLICATION_OUTCOME_RECEIVED = "application.outcome.received"

    # Agent marketplace
    AGENT_SESSION_REQUESTED = "agent.session.requested"
    AGENT_SESSION_ACCEPTED = "agent.session.accepted"
    AGENT_SESSION_COMPLETED = "agent.session.completed"

    # Notifications
    NOTIFICATION_TRIGGERED = "notification.triggered"
    NOTIFICATION_DELIVERED = "notification.delivered"

    # Payments
    PAYMENT_COMPLETED = "payment.completed"
    PAYMENT_FAILED = "payment.failed"


@dataclass
class Event:
    topic: str
    event_type: str
    payload: dict
    event_id: str = ""
    timestamp: str = ""
    version: str = "1.0"
    source_service: str = ""

    def __post_init__(self):
        if not self.event_id:
            self.event_id = str(uuid.uuid4())
        if not self.timestamp:
            self.timestamp = datetime.now(timezone.utc).isoformat()


_producer: AIOKafkaProducer | None = None


async def get_producer() -> AIOKafkaProducer:
    global _producer
    if _producer is None:
        _producer = AIOKafkaProducer(
            bootstrap_servers=settings.KAFKA_BOOTSTRAP_SERVERS,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
            key_serializer=lambda k: k.encode("utf-8") if k else None,
            acks="all",
            enable_idempotence=True,
        )
        await _producer.start()
    return _producer


async def publish_event(event: Event, key: str | None = None) -> None:
    try:
        producer = await get_producer()
        await producer.send_and_wait(
            event.topic,
            value=asdict(event),
            key=key or event.event_id,
        )
        logger.debug(f"Published event: {event.event_type} → {event.topic}")
    except Exception as e:
        logger.error(f"Failed to publish event {event.event_type}: {e}")


async def consume_events(
    topics: list[str],
    group_id: str,
    handler: Callable[[dict], Awaitable[None]],
) -> None:
    consumer = AIOKafkaConsumer(
        *topics,
        bootstrap_servers=settings.KAFKA_BOOTSTRAP_SERVERS,
        group_id=group_id,
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        auto_offset_reset="earliest",
        enable_auto_commit=False,
    )
    await consumer.start()
    try:
        async for msg in consumer:
            try:
                await handler(msg.value)
                await consumer.commit()
            except Exception as e:
                logger.error(f"Error handling event: {e}")
    finally:
        await consumer.stop()
