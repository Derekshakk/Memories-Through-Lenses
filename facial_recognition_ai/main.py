import cv2
import face_recognition, face_recognition_models
import numpy as np
import glob
import os

def get_user_face(video_path):
    video_capture = cv2.VideoCapture(video_path)
    face_encodings = []

    frame_number = 0
    success = True

    while success:
        success, frame = video_capture.read()
        if not success:
            break

        # process every 30th frame
        if frame_number % 30 == 0:
            rgb_frame = np.ascontiguousarray(frame[:, :, ::-1])

            # Find all face locations and encodings in the current frame
            face_locations = face_recognition.face_locations(rgb_frame)
            if len(face_locations) > 0:
                encodings = face_recognition.face_encodings(rgb_frame, face_locations)
                face_encodings.extend(encodings)

        frame_number += 1

    video_capture.release()

    if len(face_encodings) == 0:
        return None
    else:
        user_face_encodings = np.mean(face_encodings, axis=0)
        return user_face_encodings

def find_user_in_images(user_face_encoding, photos_path_pattern, tolerance=0.6):
    photo_paths = glob.glob(photos_path_pattern)
    matches = []

    for photo_path in photo_paths:
        image = face_recognition.load_image_file(photo_path)
        face_locations = face_recognition.face_locations(image)
        face_encodings = face_recognition.face_encodings(image, face_locations)

        for face_encoding in face_encodings:
            match = face_recognition.compare_faces([user_face_encoding], face_encoding, tolerance)
            if match[0]:
                matches.append(photo_path)
                print(f"Match found: {photo_path}")
                break

    return matches

def main():
    video_path = "demo_user.mp4"  # Path to the video file
    photos_path_pattern = "photos/*.jpg"  # Path pattern for photos

    print("Extracting user face encoding from video...")
    user_face_encoding = get_user_face(video_path)
    if user_face_encoding is None:
        print("No face found in the video.")
        return

    print("Searching for user in images...")
    matches = find_user_in_images(user_face_encoding, photos_path_pattern)
    print(f"Total matches found: {len(matches)}")

if __name__ == "__main__":
    print(face_recognition.__version__)
    print(face_recognition_models.__version__)
    main()